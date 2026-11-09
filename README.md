# 六爻 · LiuYao iOS

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

原生 SwiftUI 六爻排盘与 AI 解卦 App，支持 iOS 17 及以上。代码采用 MIT 许可，允许分享、修改和商用，分发时保留许可及版权声明。

## 功能

- 输入初爻到上爻六个数字（6、7、8、9），本地计算本卦、上下卦、动爻和变卦。
- 八宫、纳甲、六亲、世应、六神、节气月柱、日柱及旬空。
- 六十四卦离线简读、历史卦记、分享、起卦时间及时区选择。
- 自带 DeepSeek API Key：一句话总结、详细分析和连续追问。
- 可选古籍检索：按事项及卦象选取相关段落，附原文、书名、章节和 PDF 页码；追问重新检索并保留历次引用。

例如 `987887` 按初爻到上爻输入，得到第22卦山火贲，初爻动，变第52卦艮为山。

## 运行

需要 Xcode 和 Swift 5.9 或以上。打开 `LiuYao.xcodeproj`，选择 scheme `LiuYao`。真机运行前，在 Signing & Capabilities 选择自己的开发团队，并把示例 Bundle ID `com.example.liuyao` 改为自己的唯一标识。仓库未包含证书或描述文件。

也可以重新生成工程：

```sh
python3 scripts/generate_project.py
open LiuYao.xcodeproj
```

生成脚本默认不指定团队。重新生成工程会重置工程内手动修改的签名设置，请在脚本 shared/app_config 中配置自己的团队和 Bundle ID，或生成后在 Xcode 修改。

在 App 设置中输入自己的 DeepSeek Key。无需本地后端或数据库；未设置 Key 时仍可离线排盘及查阅卦典。AI 请求直接发送到 `https://api.deepseek.com/chat/completions`，用量由对应账户承担。模型支持 Flash / V4 Pro，可在设置中切换。

## 隐私与密钥

仓库不含 API Key。用户输入的 Key 仅保存到 iOS Keychain，使用 `WhenUnlockedThisDeviceOnly`，不写源码、日志或卦记。卦记保存在本机 `Documents/readings-v1.json`，原子写入并启用文件保护。

点击 AI 解卦或发送追问时，事项、时间、排盘和本轮选中书摘会发送给 DeepSeek。关闭古籍参考后不添加新的书摘；已存在的对话文字和历史引用仍保存在本机。

Debug 包含显式的本机验证入口，常规启动不执行；Release 不包含这些入口。钥匙串增删 UI 测试使用独立测试条目（`--ui-test-keychain`），不会覆盖正常条目的密钥；真实 API 验证仅在调用方显式配置的本机环境运行，不提供共享 Key。请勿提交个人历史、`.env`、签名文件或任何密钥。

## 可选古籍资料

公开仓库不附带用户私人 PDF、现代汇编及注释正文。`Sources/LiuYaoCore/Resources/classics.json` 是空占位；古籍参考默认关闭，没有资料时不能启用。排盘、离线卦典及普通 AI 解读均可直接使用。

保留了原个人版的资料处理工具；当前脚本按《六爻古籍经典合集》的书目目录结构生成索引，不是通用的任意 PDF 导入器。只导入自己有权使用的资料；不同 PDF 的字体、目录或版本需要适配。不要把个人资料索引提交到公开分支。

导入工具需要 Python 3.11 或以上。在虚拟环境中安装工具：

```sh
python3.11 -m venv build/reference-venv
source build/reference-venv/bin/activate
python -m pip install -r scripts/requirements-reference.txt
python scripts/import_classics.py '/绝对路径/你有权使用的资料.pdf'
python scripts/build_classics_index.py
swift test
```

生成后重新构建 App，再到设置启用古籍参考。工具从嵌入字体恢复字符映射，在内存中处理，原 PDF 只读；按页保留来源并建立段落索引。每轮最多选择4段、3200字正文提供给模型；全文不会整本发送。机器抽取需抽查校订。这是解卦时查阅参考资料，不是训练 DeepSeek。

## 验证

```sh
swift test
python3 scripts/generate_project.py
xcodebuild -project LiuYao.xcodeproj -scheme LiuYao -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

最后一条仅验证编译。运行 Keychain 相关模拟器 UI 测试时保留模拟器签名，禁用签名可能触发 `OSStatus -34018`。

核心测试覆盖全部4096种六爻输入、六十四卦上下卦独立对照、已知卦例、纳甲、时间边界、API响应与书摘检索。公开版的检索测试使用明确标注的人工测试数据，不依赖私人原书；原书校验和已保存回答的 UI 测试在无资料时跳过。

## 计算边界

6老阴动变阳、7少阳、8少阴、9老阳动变阴。前三爻为下卦，后三爻为上卦，所有动爻同时变化。变爻六亲以本卦宫五行为参照。月柱按北京时间精确节气切换，日柱按所选时区民用日期零点换日；支持1901—2099年，不校正真太阳时。暂不自动计算伏神或指定用神，由 AI 说明取用依据。

本地排盘结果直接提供给 AI，要求其区分原典、注释和推演，不能替换卦名或编造字段。AI 仍可能出错；本项目用于传统文化学习和个人记录。

## 许可与致谢

本项目代码及自编简明卦意采用 [MIT](LICENSE)。第三方 LunarSwift 同为 MIT，保留其原始版权及许可，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。许可不覆盖用户另行导入的资料或第三方服务。

规则交叉参考：[天机爻](https://wiki.tianjiyao.com/yijing/liuyao.html)、[FateMaster 六十四卦](https://www.fatemaster.ai/guides/64-hexagrams)、[易师汇](https://ly.yishihui.net/zh-hk/27565.htm)。网站文章不随仓库分发。
