import Foundation
import SwiftUI
import LiuYaoCore

struct ReadingRecord: Codable, Identifiable {
    var id = UUID()
    var question: String
    let numbers: [Int]
    let date: Date
    let timeZoneID: String
    var messages: [ChatMessage] = []
    var lastModel: String? = nil
    var knowledgeReferences: [KnowledgeExcerpt]? = nil
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var records: [ReadingRecord] = []
    @Published var storageError: String?
    private let fileURL: URL
    private var readable = true
    #if DEBUG
    @Published var verificationRecord: ReadingRecord?
    @Published var verificationRunning = false
    private var verificationStarted = false

    // 仅显式传入开发验证参数时执行，使用真实设备网络与钥匙串，不输出密钥。
    func verifyLiveIfRequested() async {
        guard !verificationStarted, ProcessInfo.processInfo.arguments.contains("--verify-live-ai") else { return }
        verificationStarted = true
        verificationRunning = true
        defer { verificationRunning = false }
        let receiptURL = fileURL.deletingLastPathComponent().appendingPathComponent("verification.json")
        do {
            guard let key = try KeychainStore.load() else { throw AIError.missingKey }
            var record = ReadingRecord(question: "近期这次工作调动该如何看待？（开发验证示例）", numbers: [7,7,8,9,8,7], date: Date(), timeZoneID: TimeZone.current.identifier)
            let reading = try Reading(numbers: record.numbers)
            let calendar = try CalendarContext(date: record.date, timeZoneID: record.timeZoneID)
            let model = "deepseek-flash"
            let references = ClassicsKnowledge.bundled == nil ? [] : try await ClassicsKnowledge.references(question: record.question, reading: reading)
            let answer = try await DeepSeekClient().interpret(apiKey: key, model: model, messages: DeepSeekClient.prompt(question: record.question, reading: reading, calendar: calendar, references: references))
            record.messages = [ChatMessage(role: "assistant", content: answer)]
            record.lastModel = model
            record.knowledgeReferences = references
            guard add(record) else { throw CocoaError(.fileWriteUnknown) }
            verificationRecord = record
            let receipt: [String: Any] = ["status":"passed", "recordID":record.id.uuidString, "answerCharacters":answer.count, "model":model, "keychainLoaded":true, "original":reading.original.name, "changed":reading.changed.name, "referenceCount":references.count, "referenceIDs":references.map(\.id), "referencePages":references.map(\.pdfPage)]
            try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys]).write(to: receiptURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            let receipt = ["status":"failed", "error":error.localizedDescription]
            try? JSONSerialization.data(withJSONObject: receipt).write(to: receiptURL, options: .atomic)
        }
    }
    #endif

    init() {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = root.appendingPathComponent("readings-v1.json")
        #if DEBUG
        do { try KeychainStore.importProvisionedKeyIfPresent() }
        catch { storageError = error.localizedDescription }
        #endif
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let decoded = try JSONDecoder().decode([ReadingRecord].self, from: Data(contentsOf: fileURL))
            for record in decoded {
                _ = try Reading(numbers: record.numbers)
                _ = try CalendarContext(date: record.date, timeZoneID: record.timeZoneID)
            }
            records = decoded
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--open-latest"), let record = records.first {
                verificationRecord = record
                let receipt: [String: Any] = ["status":"reloaded", "recordID":record.id.uuidString,
                                             "answerCharacters":record.messages.last?.content.count ?? 0,
                                             "recordsCount":records.count, "keychainConfigured":(try? KeychainStore.load()) != nil]
                let url = root.appendingPathComponent("reload-verification.json")
                try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys]).write(to: url, options: .atomic)
            }
            #endif
        } catch {
            readable = false
            storageError = "历史文件暂时无法读取，原文件已保留。请勿卸载 App，可联系开发者恢复。"
        }
    }

    @discardableResult
    func add(_ record: ReadingRecord) -> Bool {
        guard !records.contains(where: { $0.id == record.id }) else { return save(record) }
        return persist([record] + records)
    }

    @discardableResult
    func save(_ record: ReadingRecord) -> Bool {
        guard readable else { return false }
        var next = records
        if let index = next.firstIndex(where: { $0.id == record.id }) {
            guard record.messages.starts(with: next[index].messages) else {
                storageError = "这条卦记已有较新的解读，已保留原记录。请分享当前内容保存副本。"
                return false
            }
            next[index] = record
        }
        else {
            storageError = "这条卦记已删除，无法继续保存。当前内容可以通过分享保留。"
            return false
        }
        return persist(next)
    }

    func delete(_ id: UUID) { _ = persist(records.filter { $0.id != id }) }

    private func persist(_ next: [ReadingRecord]) -> Bool {
        guard readable else { return false }
        do {
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            records = next
            return true
        } catch {
            storageError = "未能保存到手机，请检查存储空间后重试。"
            return false
        }
    }
}
