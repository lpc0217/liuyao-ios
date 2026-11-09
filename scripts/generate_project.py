#!/usr/bin/env python3
"""生成无第三方构建工具依赖的 Xcode 工程。"""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
objects = {}

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def add(name, value):
    key = ident(name)
    objects[key] = value
    return key

def quote(value):
    return json.dumps(value, ensure_ascii=False)

def array(values):
    return '(' + ','.join(values) + (',' if values else '') + ')'

def config(name, settings):
    return add(name, '{isa = XCBuildConfiguration; buildSettings = {' + ''.join(f'{k} = {quote(str(v))};' for k,v in settings.items()) + '}; name = ' + quote(name.split('-')[-1]) + ';}')

def configs(prefix, settings):
    entries = []
    for mode in ['Debug','Release']:
        extra = {'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O'}
        if mode == 'Debug':
            extra['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
            extra['ONLY_ACTIVE_ARCH'] = 'YES'
        entries.append(config(prefix + '-' + mode, settings | extra))
    return add(prefix + '-configs', '{isa = XCConfigurationList; buildConfigurations = ' + array(entries) + '; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')

app_id = ident('app-target')
test_id = ident('test-target')
project_id = ident('project')
file_refs = []
sources = []
resources = []
for path in sorted((root/'App').rglob('*')):
    if not path.is_file() or path.suffix not in ['.swift', '.txt']:
        continue
    rel = str(path.relative_to(root))
    filetype = 'sourcecode.swift' if path.suffix == '.swift' else 'text'
    ref = add(rel, '{isa = PBXFileReference; lastKnownFileType = ' + filetype + '; path = ' + quote(rel) + '; sourceTree = "<group>";}')
    file_refs.append(ref)
    build = add(rel+'-build', '{isa = PBXBuildFile; fileRef = ' + ref + ';}')
    (sources if path.suffix == '.swift' else resources).append(build)

assets = add('assets', '{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = App/Assets.xcassets; sourceTree = "<group>";}')
file_refs.append(assets)
resources.append(add('assets-build', '{isa = PBXBuildFile; fileRef = ' + assets + ';}'))

def phase(name, kind, files):
    return add(name, '{isa = '+kind+'; buildActionMask = 2147483647; files = '+array(files)+'; runOnlyForDeploymentPostprocessing = 0;}')

package = add('local-package', '{isa = XCLocalSwiftPackageReference; relativePath = .;}')
product = add('core-product', '{isa = XCSwiftPackageProductDependency; productName = LiuYaoCore;}')
link = add('core-link', '{isa = PBXBuildFile; productRef = '+product+';}')
app_phases = [phase('app-sources','PBXSourcesBuildPhase',sources), phase('app-frameworks','PBXFrameworksBuildPhase',[link]), phase('app-resources','PBXResourcesBuildPhase',resources)]
app_product = add('app-product', '{isa = PBXFileReference; explicitFileType = wrapper.application; path = LiuYao.app; sourceTree = BUILT_PRODUCTS_DIR;}')
test_product = add('test-product', '{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = LiuYaoUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
test_ref = add('test-file', '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UITests/LiuYaoUITests.swift; sourceTree = "<group>";}')
file_refs.append(test_ref)
test_build = add('test-build', '{isa = PBXBuildFile; fileRef = '+test_ref+';}')
test_phases = [phase('test-sources','PBXSourcesBuildPhase',[test_build]), phase('test-frameworks','PBXFrameworksBuildPhase',[])]
products_group = add('products-group', '{isa = PBXGroup; children = '+array([app_product,test_product])+'; name = Products; sourceTree = "<group>";}')
main_group = add('main-group', '{isa = PBXGroup; children = '+array(file_refs+[products_group])+'; sourceTree = "<group>";}')

shared = {'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','GENERATE_INFOPLIST_FILE':'YES','SWIFT_EMIT_LOC_STRINGS':'YES'}
app_config = configs('app', shared | {'PRODUCT_BUNDLE_IDENTIFIER':'com.example.liuyao','PRODUCT_NAME':'$(TARGET_NAME)','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','INFOPLIST_KEY_CFBundleDisplayName':'六爻','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.lifestyle','INFOPLIST_KEY_ITSAppUsesNonExemptEncryption':'NO','INFOPLIST_KEY_CFBundleDevelopmentRegion':'zh_CN'})
test_config = configs('test', shared | {'PRODUCT_BUNDLE_IDENTIFIER':'com.example.liuyao.uitests','PRODUCT_NAME':'$(TARGET_NAME)','TEST_TARGET_NAME':'LiuYao'})
proxy = add('app-proxy', '{isa = PBXContainerItemProxy; containerPortal = '+project_id+'; proxyType = 1; remoteGlobalIDString = '+app_id+'; remoteInfo = LiuYao;}')
dependency = add('test-dependency', '{isa = PBXTargetDependency; target = '+app_id+'; targetProxy = '+proxy+';}')
add('app-target', '{isa = PBXNativeTarget; buildConfigurationList = '+app_config+'; buildPhases = '+array(app_phases)+'; buildRules = (); dependencies = (); name = LiuYao; productName = LiuYao; productReference = '+app_product+'; productType = "com.apple.product-type.application"; packageProductDependencies = '+array([product])+';}')
add('test-target', '{isa = PBXNativeTarget; buildConfigurationList = '+test_config+'; buildPhases = '+array(test_phases)+'; buildRules = (); dependencies = '+array([dependency])+'; name = LiuYaoUITests; productName = LiuYaoUITests; productReference = '+test_product+'; productType = "com.apple.product-type.bundle.ui-testing";}')
project_config = configs('project', {'CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_VERSION':'5.0','ENABLE_USER_SCRIPT_SANDBOXING':'YES'})
add('project', '{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = {'+test_id+' = {TestTargetID = '+app_id+';};};}; buildConfigurationList = '+project_config+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; knownRegions = (zh_CN,en,Base); mainGroup = '+main_group+'; productRefGroup = '+products_group+'; projectDirPath = ""; projectRoot = ""; targets = '+array([app_id,test_id])+'; packageReferences = '+array([package])+';}')

project = root/'LiuYao.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project_id+';}\n')
schemes = project/'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
def reference(target, name, buildable):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{buildable}" BlueprintName="{name}" ReferencedContainer="container:LiuYao.xcodeproj"/>'
app_ref = reference(app_id,'LiuYao','LiuYao.app')
test_reference = reference(test_id,'LiuYaoUITests','LiuYaoUITests.xctest')
(schemes/'LiuYao.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{test_reference}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_reference}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated LiuYao.xcodeproj')
