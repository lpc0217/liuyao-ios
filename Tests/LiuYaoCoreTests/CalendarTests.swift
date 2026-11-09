import XCTest
@testable import LiuYaoCore

final class CalendarTests: XCTestCase {
    func testKnownDateHasExpectedDayMonthAndVoid() throws {
        let context = try CalendarContext(date: date("2005-12-23T00:37:00Z"), timeZoneID: "Asia/Shanghai")
        XCTAssertEqual(context.year, "乙酉")
        XCTAssertEqual(context.month, "戊子")
        XCTAssertEqual(context.day, "辛巳")
        XCTAssertEqual(context.voidBranches, "申酉")
        XCTAssertEqual(context.dayStem, "辛")
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    func testSameInstantUsesSelectedLocalDayAndSameSeasonalMonth() throws {
        let instant = date("2005-12-23T00:37:00Z")
        let toronto = try CalendarContext(date: instant, timeZoneID: "America/Toronto")
        let shanghai = try CalendarContext(date: instant, timeZoneID: "Asia/Shanghai")
        XCTAssertEqual(toronto.day, "庚辰")
        XCTAssertEqual(shanghai.day, "辛巳")
        XCTAssertEqual(toronto.month, shanghai.month)
    }

    func testZeroHourChangesDayButTwentyThreeDoesNot() throws {
        let before = try CalendarContext(date: date("2005-12-22T15:30:00Z"), timeZoneID: "Asia/Shanghai")
        let after = try CalendarContext(date: date("2005-12-22T16:00:00Z"), timeZoneID: "Asia/Shanghai")
        XCTAssertEqual(before.day, "庚辰")
        XCTAssertEqual(after.day, "辛巳")
    }

    func testRejectsUnknownTimeZone() {
        XCTAssertThrowsError(try CalendarContext(date: Date(), timeZoneID: "Invalid/Zone"))
    }
}
