import Foundation

public struct KnowledgeBook: Codable, Identifiable, Sendable {
    public let title: String
    public let startPage: Int
    public let endPage: Int
    public var id: String { title }
}

public struct KnowledgeExcerpt: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let book: String
    public let chapter: String
    public let pdfPage: Int
    public let text: String
    public var citation: String { "《\(book)》·\(chapter)·PDF第\(pdfPage)页 [\(id)]" }
}

public struct ClassicsKnowledge: Decodable, Sendable {
    public let title: String
    public let sourceSHA256: String
    public let pageCount: Int
    public let characterCount: Int
    public let books: [KnowledgeBook]
    public let passages: [KnowledgeExcerpt]

    public static let bundled: ClassicsKnowledge? = {
        guard let url = Bundle.module.url(forResource: "classics", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(ClassicsKnowledge.self, from: data),
              !library.passages.isEmpty else { return nil }
        return library
    }()

    public static func references(question: String, reading: Reading) async throws -> [KnowledgeExcerpt] {
        try await Task.detached(priority: .userInitiated) {
            guard let library = Self.bundled else { throw KnowledgeError.unavailable }
            return library.retrieve(question: question, reading: reading)
        }.value
    }

    public func retrieve(question: String, reading: Reading) -> [KnowledgeExcerpt] {
        let topics = Self.topics.filter { topic in topic.questions.contains { question.contains($0) } }
            .flatMap(\.chapters)
        let normalized = question.replacingOccurrences(of: "[^\\p{Han}]", with: "", options: .regularExpression)
        let characters = Array(normalized.prefix(256))
        let ignored: Set<String> = ["我的", "这个", "这次", "一下", "是否", "如何", "能否", "什么", "可以", "怎么"]
        let queryTerms = characters.count < 2 ? [] : Array(Set((0..<(characters.count - 1)).map {
            String(characters[$0...($0+1)])
        }).subtracting(ignored)).sorted().prefix(40).map { $0 }

        func score(_ passage: KnowledgeExcerpt) -> Int {
            let titleMatches = topics.filter { passage.chapter.contains($0) }.count
            let bodyMatches = topics.filter { passage.text.contains($0) }.count
            var value = min(titleMatches, 2) * 40 + min(bodyMatches, 4) * 3
            value += queryTerms.filter { passage.text.contains($0) }.count
            value += queryTerms.filter { passage.chapter.contains($0) }.count * 4
            for hexagram in [reading.original, reading.changed] {
                if passage.text.contains(hexagram.name) { value += 5 }
                if passage.chapter.contains(hexagram.shortName + "卦") { value += 8 }
            }
            let movementTerms = reading.movingPositions.isEmpty ? ["静卦", "动静"] : ["动变", "独发"]
            if movementTerms.contains(where: { passage.chapter.contains($0) }) { value += 5 }
            if value > 0, passage.book == "增删卜易" || passage.book == "卜筮正宗" { value += 8 }
            return value
        }

        let scored: [(KnowledgeExcerpt, Int)] = passages.map { passage in (passage, score(passage)) }
        var ranked = scored.filter { $0.1 > 0 }
        ranked.sort { left, right in
            if left.1 == right.1 { return left.0.id < right.0.id }
            return left.1 > right.1
        }
        var selected: [KnowledgeExcerpt] = []
        // 先保留取用原则，再选与事项、卦象匹配的段落；不把某个古例硬套到现代问题。
        if let foundation = passages.first(where: { $0.book == "增删卜易" && $0.text.contains("先看何爻为用神") }) {
            selected.append(foundation)
        }
        for distinctChapter in [true, false] {
            for (candidate, _) in ranked {
                guard selected.count < 4 else { break }
                guard !selected.contains(where: { $0.pdfPage == candidate.pdfPage }) else { continue }
                if distinctChapter && selected.contains(where: { $0.book == candidate.book && $0.chapter == candidate.chapter }) { continue }
                guard selected.reduce(0, { $0 + $1.text.count }) + candidate.text.count <= 3200 else { continue }
                selected.append(candidate)
            }
        }
        return selected
    }

    private struct Topic {
        let questions: [String]
        let chapters: [String]
    }
    private static let topics: [Topic] = [
        .init(questions: ["工作","升职","升迁","调动","调岗","职位","事业","求职","面试","岗位"], chapters: ["求名","仕宦","升迁","功名","求官","官职"]),
        .init(questions: ["财","钱","生意","投资","买卖","收入","利润","合同","薪资","工资","待遇"], chapters: ["求财","贸易","买卖","财爻"]),
        .init(questions: ["感情","婚","恋","伴侣","男友","女友","分手","复合"], chapters: ["婚姻","婚娶","姻缘","夫妇"]),
        .init(questions: ["考试","考研","学习","学业","考证","录取"], chapters: ["考试","科考","童试","岁考","学业","读书"]),
        .init(questions: ["出行","旅行","出差","远行","搬家"], chapters: ["出行","迁移","行人"]),
        .init(questions: ["房","住宅","租赁","买地"], chapters: ["家宅","宅舍","地理","田产"]),
        .init(questions: ["健康","病","治疗","身体","医"], chapters: ["疾病","医药"]),
        .init(questions: ["丢失","失物","找回","遗失"], chapters: ["失物","失脱"]),
        .init(questions: ["诉讼","官司","纠纷","打官司"], chapters: ["词讼","争讼","诉讼"])
    ]
}

public enum KnowledgeError: LocalizedError {
    case unavailable
    public var errorDescription: String? { "古籍资料未导入或未能加载。请先导入有权使用的资料并重新构建，或关闭古籍参考后重试。" }
}
