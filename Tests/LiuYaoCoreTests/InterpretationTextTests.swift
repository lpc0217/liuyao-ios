import XCTest
@testable import LiuYaoCore

final class InterpretationTextTests: XCTestCase {
    func testSeparatesSummaryFromDetailedInterpretation() {
        let text = InterpretationText("## 一句话总结\n\n宜稳住节奏，先理清分歧再推进。\n\n## 卦象概览\n山火贲初爻动。")
        XCTAssertEqual(text.summary, "宜稳住节奏，先理清分歧再推进。")
        XCTAssertEqual(text.details, "## 卦象概览\n山火贲初爻动。")
    }

    func testPreservesOldAnswerWithoutSummary() {
        let answer = "## 卦象概览\n原有的完整解读。"
        XCTAssertNil(InterpretationText(answer).summary)
        XCTAssertEqual(InterpretationText(answer).details, answer)
    }
}
