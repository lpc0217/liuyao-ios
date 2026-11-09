import SwiftUI
import LiuYaoCore

struct ReadingDetailView: View {
    @EnvironmentObject private var store: AppStore
    private let initialRecord: ReadingRecord
    @State private var unsavedRecord: ReadingRecord?
    @State private var draftQuestion: String
    @State private var pending: Task<Void, Never>?
    @State private var loading = false
    @State private var error: String?
    @State private var followUp = ""
    @State private var showSettings = false
    @AppStorage("deepseek-model") private var model = "deepseek-flash"
    @AppStorage("use-classics-reference") private var useClassics = false
    @FocusState private var focused: Bool

    init(record: ReadingRecord) {
        initialRecord = record
        _draftQuestion = State(initialValue: record.question)
    }

    private var record: ReadingRecord {
        unsavedRecord ?? store.records.first(where: { $0.id == initialRecord.id }) ?? initialRecord
    }

    var body: some View {
        ScrollView {
            if !store.records.contains(where: { $0.id == initialRecord.id }) {
                ContentUnavailableView("卦记已删除", systemImage: "doc", description: Text("请返回起卦。当前内容仍可从右上角分享保留。"))
            } else if let reading = try? Reading(numbers: record.numbers),
               let calendar = try? CalendarContext(date: record.date, timeZoneID: record.timeZoneID) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.question.isEmpty ? "此卦无题" : record.question)
                            .font(.title2.weight(.medium)).textSelection(.enabled)
                        Text("\(calendar.localDate)\n\(calendar.timeZoneID)")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }.padding(.top, 8)
                    HStack(alignment: .top, spacing: 24) {
                        HexagramPanel(hexagram: reading.original, label: "本卦", moving: reading.movingPositions)
                        HexagramPanel(hexagram: reading.changed, label: reading.movingPositions.isEmpty ? "静卦，无变化" : "变卦")
                    }
                    HStack {
                        Text("\(reading.original.palace.name)宫属\(reading.original.palace.element.rawValue)　\(reading.original.stage)")
                        Spacer()
                        Text(reading.movingPositions.isEmpty ? "无动爻" : "\(reading.movingPositions.map(String.init).joined(separator: "、"))爻动")
                    }.font(.subheadline).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(title: "纳甲排盘", note: "自上而下")
                        Text("\(calendar.year)年　\(calendar.month)月　\(calendar.day)日\n旬空：\(calendar.voidBranches)")
                            .font(.subheadline).lineSpacing(5)
                        Divider().overlay(Theme.ink)
                        ForEach(reading.lines(dayStem: calendar.dayStem).reversed()) { line in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(line.label)　\(line.god)").font(.caption).foregroundStyle(Theme.muted)
                                    Text("\(line.relative) \(line.stemBranch)\(line.element.rawValue)").font(.subheadline)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                YaoMark(yang: line.yang, moving: line.moving).frame(width: 60)
                                Text(line.isSelf ? "世" : line.isOther ? "应" : " ")
                                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent).frame(width: 20)
                                Text(line.moving ? (line.yang ? "○" : "×") : "静")
                                    .font(.subheadline).foregroundStyle(line.moving ? Theme.accent : Theme.muted).frame(width: 20)
                            }.padding(.vertical, 5)
                            if line.moving {
                                Text("化 \(line.changedRelative) \(line.changedStemBranch)\(line.changedElement.rawValue)")
                                    .font(.caption).foregroundStyle(Theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            Divider()
                        }
                        DisclosureGroup("历法与排盘约定") {
                            Text(CalendarContext.convention + "变爻六亲以本卦宫五行确定。世应标注属于本卦；伏神与用神未自动指定。")
                                .font(.caption).foregroundStyle(Theme.muted).padding(.top, 8)
                        }.font(.caption)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "读懂卦意")
                        NavigationLink { HexagramInfoView(hexagram: reading.original) } label: {
                            MeaningRow(hexagram: reading.original)
                        }.buttonStyle(.plain)
                        if !reading.movingPositions.isEmpty {
                            NavigationLink { HexagramInfoView(hexagram: reading.changed) } label: {
                                MeaningRow(hexagram: reading.changed)
                            }.buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "AI 解卦", note: "DeepSeek")
                        if record.messages.isEmpty {
                            Group {
                                TextField("补充所问事项，再开始解读", text: $draftQuestion, axis: .vertical)
                                    .lineLimit(2...4).padding(12).background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))
                                    .focused($focused)
                                    .disabled(loading)
                                    .onChange(of: draftQuestion) { _, value in
                                        if value.count > 2000 { draftQuestion = String(value.prefix(2000)); return }
                                        var updated = record
                                        updated.question = value
                                        if store.save(updated) { unsavedRecord = nil } else { unsavedRecord = updated }
                                    }
                            }
                            Text("结合所问事项、动爻和日月，解释判断依据。点击后会将问题与排盘发送给 DeepSeek。")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                            if useClassics {
                                Text("已启用古籍参考，解读将结合相关书摘并注明出处。")
                                    .font(.caption).foregroundStyle(Theme.accent)
                            }
                            Button("开始 AI 解卦") { generate(reading: reading, calendar: calendar) }
                                .buttonStyle(PrimaryButton()).disabled(loading)
                                .accessibilityIdentifier("interpret")
                        } else {
                            ForEach(Array(record.messages.enumerated()), id: \.offset) { _, message in
                                if message.role == "user" {
                                    Text(message.content).font(.headline).padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 8))
                                } else {
                                    AnswerText(content: message.content)
                                }
                            }
                            TextField("继续问这张卦", text: $followUp, axis: .vertical)
                                .lineLimit(2...4).padding(12).background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))
                                .focused($focused)
                                .onChange(of: followUp) { _, value in if value.count > 2000 { followUp = String(value.prefix(2000)) } }
                            Button("发送追问") { generate(reading: reading, calendar: calendar, followUp: followUp) }
                                .buttonStyle(PrimaryButton()).disabled(loading || followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let references = record.knowledgeReferences, !references.isEmpty {
                            KnowledgeSourcesView(references: references)
                        }
                        if loading {
                            HStack { ProgressView(); Text("正在解卦，请稍候…").font(.subheadline); Spacer(); Button("取消") { pending?.cancel() } }
                        }
                        if let unsavedRecord {
                            Text("当前内容尚未保存，请重试保存；也可用右上角分享保留。")
                                .font(.subheadline).foregroundStyle(Theme.accent)
                            Button("重试保存") { if store.save(unsavedRecord) { self.unsavedRecord = nil } }
                        }
                        if let error {
                            Text(error).font(.subheadline).foregroundStyle(Theme.accent).textSelection(.enabled)
                            Button("打开 API 设置") { showSettings = true }.font(.subheadline)
                        }
                        Text("传统文化解读，供学习与思考。")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }.padding(.horizontal, 24).padding(.bottom, 30)
            }
        }.background(Theme.paper).foregroundStyle(Theme.ink)
            .navigationTitle("卦象").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focused = false } }
            }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView().toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { showSettings = false } } } } }
            .onDisappear { pending?.cancel() }
            .onAppear { draftQuestion = record.question }
    }

    private var shareText: String {
        guard let reading = try? Reading(numbers: record.numbers),
              let calendar = try? CalendarContext(date: record.date, timeZoneID: record.timeZoneID) else { return "" }
        let chart = reading.lines(dayStem: calendar.dayStem).reversed().map {
            "\($0.label) \($0.number) \($0.relative) \($0.stemBranch)\($0.element.rawValue) \($0.god)\($0.isSelf ? " 世" : "")\($0.isOther ? " 应" : "")\($0.moving ? " 动" : "")"
        }.joined(separator: "\n")
        return "\(record.question)\n\(calendar.localDate) \(record.timeZoneID)\n\(calendar.year)年 \(calendar.month)月 \(calendar.day)日 旬空\(calendar.voidBranches)\n\(reading.original.name) → \(reading.changed.name)\n初爻至上爻：\(record.numbers.map(String.init).joined(separator: "、"))\n\(chart)\n\n" + record.messages.map { $0.content }.joined(separator: "\n\n")
    }

    private func generate(reading: Reading, calendar: CalendarContext, followUp: String? = nil) {
        guard !loading else { return }
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { error = "请先补充所问事项。"; return }
        do {
            guard let key = try KeychainStore.load(), !key.isEmpty else { error = AIError.missingKey.localizedDescription; return }
            let follow = followUp?.trimmingCharacters(in: .whitespacesAndNewlines)
            loading = true
            error = nil
            focused = false
            let requestedModel = model
            let baseRecord = record
            let includeClassics = useClassics
            pending = Task { @MainActor in
                defer { loading = false; pending = nil }
                do {
                    var references: [KnowledgeExcerpt] = []
                    if includeClassics {
                        let retrievalQuestion = follow.flatMap { $0.isEmpty ? nil : $0 } ?? question
                        references = try await ClassicsKnowledge.references(question: retrievalQuestion, reading: reading)
                    }
                    try Task.checkCancellation()
                    var messages = DeepSeekClient.prompt(question: question, reading: reading, calendar: calendar, references: references) + baseRecord.messages
                    if let follow, !follow.isEmpty { messages.append(ChatMessage(role: "user", content: follow)) }
                    let answer = try await DeepSeekClient().interpret(apiKey: key, model: requestedModel, messages: messages)
                    try Task.checkCancellation()
                    var updated = baseRecord
                    if let follow, !follow.isEmpty { updated.messages.append(ChatMessage(role: "user", content: follow)) }
                    updated.question = question
                    updated.messages.append(ChatMessage(role: "assistant", content: answer))
                    updated.lastModel = requestedModel
                    if !references.isEmpty {
                        var remembered = updated.knowledgeReferences ?? []
                        for reference in references where !remembered.contains(where: { $0.id == reference.id }) { remembered.append(reference) }
                        updated.knowledgeReferences = remembered
                    }
                    if store.save(updated) { unsavedRecord = nil; self.followUp = "" }
                    else { unsavedRecord = updated }
                } catch is CancellationError {
                    self.error = "已取消解卦，可以重新发送。"
                } catch let network as URLError where network.code == .cancelled {
                    self.error = "已取消解卦，可以重新发送。"
                } catch {
                    self.error = error.localizedDescription
                }
            }
        } catch { self.error = error.localizedDescription }
    }
}

struct HexagramPanel: View {
    let hexagram: Hexagram
    let label: String
    var moving: [Int] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.subheadline).foregroundStyle(Theme.muted)
            VStack(spacing: 12) {
                ForEach((0..<6).reversed(), id: \.self) { index in
                    YaoMark(yang: hexagram.bits & (1 << index) != 0, moving: moving.contains(index + 1))
                }
            }.frame(maxWidth: 140).padding(.vertical, 8).accessibilityElement(children: .ignore)
                .accessibilityLabel("\(hexagram.name)，上\(hexagram.upper.name)下\(hexagram.lower.name)")
            Text(hexagram.name).font(.title3.weight(.semibold)).minimumScaleFactor(0.8)
                .accessibilityIdentifier(label == "本卦" ? "original-name" : "changed-name")
            Text("第\(hexagram.number)卦　上\(hexagram.upper.name)下\(hexagram.lower.name)")
                .font(.caption).foregroundStyle(Theme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MeaningRow: View {
    let hexagram: Hexagram
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(hexagram.name).font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption) }
            Text(hexagram.meaning).font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
        }.padding(.vertical, 8)
    }
}

struct AnswerText: View {
    let content: String
    var body: some View {
        let interpretation = InterpretationText(content)
        VStack(alignment: .leading, spacing: 9) {
            if let summary = interpretation.summary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("一句话总结").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text(.init(summary)).font(.headline).lineSpacing(5)
                        .accessibilityIdentifier("interpretation-summary")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 8)
            }
            ForEach(Array(interpretation.details.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("#") {
                    Text(line.drop(while: { $0 == "#" || $0 == " " })).font(.headline).padding(.top, 8)
                } else if !line.isEmpty {
                    Text(.init(line)).font(.body).lineSpacing(5)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
    }
}
