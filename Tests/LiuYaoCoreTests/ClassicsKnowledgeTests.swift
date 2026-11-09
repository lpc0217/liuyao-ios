import XCTest
@testable import LiuYaoCore

final class ClassicsKnowledgeTests: XCTestCase {
    // 人工测试数据，仅用于验证检索行为，不是所列古籍的真实原文。
    private func testLibrary() throws -> ClassicsKnowledge {
        let chapters = ["用神章", "求名仕宦升迁", "求财贸易", "婚姻章", "动变章"]
        let texts = ["测试数据：先看何爻为用神，须结合所问事项。", "测试数据：工作职位、求名与仕宦升迁相关。", "测试数据：薪资待遇、买卖利润与求财贸易相关。", "测试数据：婚姻伴侣事项。", "测试数据：区分动变与静卦。"]
        let passages: [[String: Any]] = chapters.indices.map { index in
            ["id": "TEST-\(index)", "book": "增删卜易", "chapter": chapters[index], "pdfPage": index + 1, "text": texts[index]]
        }
        let data = try JSONSerialization.data(withJSONObject: ["title": "人工测试资料", "sourceSHA256": "", "pageCount": 5, "characterCount": 100, "books": [], "passages": passages])
        return try JSONDecoder().decode(ClassicsKnowledge.self, from: data)
    }

    func testBundledLibraryIncludesRepairedTextAndSevenBooks() throws {
        guard let library = ClassicsKnowledge.bundled else { throw XCTSkip("公开版不分发私人书籍正文。") }
        XCTAssertEqual(library.pageCount, 1517)
        XCTAssertEqual(library.books.count, 7)
        XCTAssertTrue(library.passages.contains { $0.pdfPage == 33 && $0.text.contains("金生水，水生木") })
        XCTAssertTrue(library.passages.contains { $0.pdfPage == 36 && $0.text.contains("动而必变") })
    }

    func testRetrievesCareerChaptersForModernWorkQuestion() throws {
        let library = try testLibrary()
        let reading = try Reading(numbers: [9,8,7,8,8,7])
        let selected = library.retrieve(question: "我这次工作调动、升职是否合适？", reading: reading)
        XCTAssertTrue(selected.contains { $0.chapter.contains("求名") || $0.chapter.contains("仕宦") || $0.chapter.contains("升迁") })
        XCTAssertTrue(selected.contains { $0.text.contains("用神") })
        XCTAssertLessThanOrEqual(selected.count, 4)
        XCTAssertLessThanOrEqual(selected.reduce(0) { $0 + $1.text.count }, 3200)
        XCTAssertEqual(Set(selected.map(\.pdfPage)).count, selected.count)
    }

    func testRetrievesFinanceInsteadOfMarriageChaptersForMoneyQuestion() throws {
        let library = try testLibrary()
        let selected = library.retrieve(question: "这次买卖能不能获得利润，如何看求财？", reading: try Reading(numbers: [7,7,8,9,8,7]))
        XCTAssertTrue(selected.contains { $0.chapter.contains("求财") || $0.chapter.contains("贸易") })
        XCTAssertFalse(selected.contains { $0.chapter == "婚姻章" })
    }

    func testSalaryFollowUpRetrievesFinanceChapters() throws {
        let library = try testLibrary()
        let selected = library.retrieve(question: "薪资待遇如何？", reading: try Reading(numbers: [9,8,7,8,8,7]))
        XCTAssertTrue(selected.contains { $0.chapter.contains("求财") || $0.chapter.contains("贸易") })
    }

    func testPromptIncludesOnlySelectedSourcesAndTheirRealPages() throws {
        let library = try testLibrary()
        let reading = try Reading(numbers: [9,8,7,8,8,7])
        let references = library.retrieve(question: "工作调动", reading: reading)
        let calendar = try CalendarContext(date: Date(), timeZoneID: "America/Toronto")
        let prompt = DeepSeekClient.prompt(question: "工作调动", reading: reading, calendar: calendar, references: references)
        let sourceText = try XCTUnwrap(prompt.last?.content)
        for reference in references {
            XCTAssertTrue(sourceText.contains(reference.citation))
            XCTAssertTrue(sourceText.contains(reference.text))
        }
        XCTAssertTrue(prompt[0].content.contains("参考数据"))
        let withoutSources = DeepSeekClient.prompt(question: "工作调动", reading: reading, calendar: calendar)
        XCTAssertFalse(withoutSources.last!.content.contains("<古籍书摘>"))
    }
}
