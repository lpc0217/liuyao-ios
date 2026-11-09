import SwiftUI
import LiuYaoCore

struct SettingsView: View {
    @State private var key = ""
    @State private var saved = false
    @State private var message: String?
    @State private var removeKey = false
    @AppStorage("deepseek-model") private var model = "deepseek-flash"
    @AppStorage("use-classics-reference") private var useClassics = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section {
                HStack { Label("DeepSeek API Key", systemImage: "key"); Spacer(); Text(saved ? "已保存" : "未配置").foregroundStyle(saved ? Theme.ink : Theme.muted).accessibilityIdentifier("key-status") }
                SecureField(saved ? "输入新 Key 可替换原 Key" : "在此粘贴 API Key", text: $key)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .privacySensitive().accessibilityIdentifier("api-key")
                Button("保存到此 iPhone") { saveKey() }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-key")
                if saved {
                    Button("移除 API Key", role: .destructive) { removeKey = true }.accessibilityIdentifier("remove-key")
                }
                if let message { Text(message).font(.subheadline).foregroundStyle(Theme.accent) }
            } header: { Text("个人直连") } footer: {
                Text("密钥仅存于本机钥匙串，解锁后使用，不写入代码或卦记。点击 AI 解卦时直接请求 DeepSeek，费用由你的账户承担。")
            }
            Section("解读模型") {
                Picker("模型", selection: $model) {
                    Text("DeepSeek Flash").tag("deepseek-flash")
                    Text("DeepSeek V4 Pro").tag("deepseek-v4-pro")
                }
                Text("排盘在手机本地完成，无需网络。AI 解读需要联网。")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
            Section {
                Toggle("解卦时参考古籍", isOn: $useClassics).accessibilityIdentifier("use-classics")
                    .disabled(ClassicsKnowledge.bundled == nil)
                NavigationLink("已导入的古籍资料") { ClassicsReferenceView() }.accessibilityIdentifier("classics-library")
            } header: { Text("古籍参考") } footer: {
                Text("可选功能，公开版不附带书籍正文。导入自己的合法资料并重新构建后，可启用相关书摘参考；仅在解卦时发送选中段落给 DeepSeek。")
            }
            Section("规则与资料") {
                NavigationLink("六爻录入规则") { RulesView() }
                Link("天机爻：六爻入门", destination: URL(string: "https://wiki.tianjiyao.com/yijing/liuyao.html")!)
                Link("FateMaster：六十四卦", destination: URL(string: "https://www.fatemaster.ai/guides/64-hexagrams")!)
                Link("易师汇：分类卦意参考", destination: URL(string: "https://ly.yishihui.net/zh-hk/27565.htm")!)
                NavigationLink("开源许可") { LicenseView() }
            }
            Section {
                Text("六爻 1.0（1）").foregroundStyle(Theme.muted)
                Text("个人使用版。卦典为独立编写的简要卦意，AI 解读不代表确定结果。")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }.scrollContentBackground(.hidden).background(Theme.paper).foregroundStyle(Theme.ink)
            .navigationTitle("设置")
            .onAppear { refreshStatus() }
            .onDisappear { key = "" }
            .onChange(of: scenePhase) { _, phase in if phase != .active { key = "" } }
            .confirmationDialog("移除此 iPhone 保存的 API Key？", isPresented: $removeKey, titleVisibility: .visible) {
                Button("移除密钥", role: .destructive) {
                    do { try KeychainStore.remove(); saved = false; key = ""; message = "密钥已移除。" }
                    catch { message = error.localizedDescription }
                }
            }
    }
    private func refreshStatus() {
        do { saved = try KeychainStore.load() != nil }
        catch { message = error.localizedDescription }
    }
    private func saveKey() {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !cleaned.contains(where: { $0.isWhitespace }) else { message = "API Key 中不能包含空格或换行。"; return }
        do { try KeychainStore.save(cleaned); key = ""; saved = true; message = "已安全保存。可返回卦象页面开始解读。" }
        catch { message = error.localizedDescription }
    }
}

struct RulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("从下往上，六次成卦").font(.title2.weight(.semibold))
                Text("第一次得到的数是初爻，位于卦象最下方；第六次是上爻。输入页按摇卦先后排列，结果页按卦象上下排列。")
                ForEach(["6　老阴：阴爻，动而变阳", "7　少阳：阳爻，不变", "8　少阴：阴爻，不变", "9　老阳：阳爻，动而变阴"], id: \.self) { Text($0) }
                Text("初、二、三爻组成下卦；四、五、上爻组成上卦。所有动爻同时变化得到变卦。没有 6 和 9 时为静卦。")
                Text("六亲按本卦所属八宫的五行确定；六神按起卦日干起排。月柱按北京时间节气交节，日柱按所选时区零点换日。")
                Text("先写清所问事项。AI 会说明取用依据，资料不足时应先补充信息。")
            }.lineSpacing(6).padding(24)
        }.background(Theme.paper).foregroundStyle(Theme.ink).navigationTitle("录入规则").navigationBarTitleDisplayMode(.inline)
    }
}

struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text(licenseText)
                .font(.footnote).textSelection(.enabled).padding(24)
        }.background(Theme.paper).navigationTitle("开源许可")
    }
    private var licenseText: String {
        ["LiuYao-LICENSE", "LunarSwift-LICENSE"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n")
    }
}
