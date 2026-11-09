import XCTest
@testable import LiuYaoCore

final class ReadingTests: XCTestCase {
    func test987887IsBiChangingFirstLineIntoGen() throws {
        let reading = try Reading(numbers: [9,8,7,8,8,7])
        XCTAssertEqual(reading.original.number, 22)
        XCTAssertEqual(reading.original.name, "山火贲")
        XCTAssertEqual(reading.original.lower.name, "离")
        XCTAssertEqual(reading.original.upper.name, "艮")
        XCTAssertEqual(reading.movingPositions, [1])
        XCTAssertEqual(reading.changed.number, 52)
        XCTAssertEqual(reading.changed.name, "艮为山")
        XCTAssertEqual(reading.changed.lower.name, "艮")
        XCTAssertEqual(reading.changed.upper.name, "艮")
    }

    func testKuiFourthLineChangesUpperTrigramIntoSun() throws {
        let reading = try Reading(numbers: [7, 7, 8, 9, 8, 7])
        XCTAssertEqual(reading.originalName, "火泽睽")
        XCTAssertEqual(reading.changedName, "山泽损")
        XCTAssertEqual(reading.movingPositions, [4])
    }

    func testRejectsIncompleteAndOutOfRangeInput() {
        for numbers in [[7,7], [7,7,7,7,7,5], [7,7,7,7,7,10], []] {
            XCTAssertThrowsError(try Reading(numbers: numbers))
        }
    }

    func testAllOldYinChangesEarthIntoHeaven() throws {
        let reading = try Reading(numbers: [6,6,6,6,6,6])
        XCTAssertEqual(reading.original.name, "坤为地")
        XCTAssertEqual(reading.changed.name, "乾为天")
        XCTAssertEqual(reading.movingPositions, [1,2,3,4,5,6])
    }

    func testStaticHeavenHasNoMovingLines() throws {
        let reading = try Reading(numbers: [7,7,7,7,7,7])
        XCTAssertEqual(reading.original.number, 1)
        XCTAssertEqual(reading.changed.number, 1)
        XCTAssertEqual(reading.movingPositions, [])
        let lines = reading.lines(dayStem: "甲")
        XCTAssertEqual(lines.map(\.stemBranch), ["甲子","甲寅","甲辰","壬午","壬申","壬戌"])
        XCTAssertEqual(lines.map(\.relative), ["子孙","妻财","父母","官鬼","兄弟","父母"])
        XCTAssertEqual(lines.filter(\.isSelf).map(\.position), [6])
        XCTAssertEqual(lines.filter(\.isOther).map(\.position), [3])
        XCTAssertEqual(lines.map(\.god), ["青龙","朱雀","勾陈","螣蛇","白虎","玄武"])
    }

    func testChangedRelativesUseOriginalPalace() throws {
        let reading = try Reading(numbers: [6,6,6,6,6,6])
        XCTAssertEqual(reading.lines(dayStem: "戊").first?.changedRelative, "妻财")
    }

    func testKingWenSequenceAgainstIndependentTrigramTable() {
        // 文王卦序；每对为上、下经卦，独立于八宫变爻生成表。
        let pairs = ["乾乾","坤坤","坎震","艮坎","坎乾","乾坎","坤坎","坎坤",
                     "巽乾","乾兑","坤乾","乾坤","乾离","离乾","坤艮","震坤",
                     "兑震","艮巽","坤兑","巽坤","离震","艮离","艮坤","坤震",
                     "乾震","艮乾","艮震","兑巽","坎坎","离离","兑艮","震巽",
                     "乾艮","震乾","离坤","坤离","巽离","离兑","坎艮","震坎",
                     "艮兑","巽震","兑乾","乾巽","兑坤","坤巽","兑坎","坎巽",
                     "兑离","离巽","震震","艮艮","巽艮","震兑","震离","离艮",
                     "巽巽","兑兑","巽坎","坎兑","巽兑","震艮","坎离","离坎"]
        XCTAssertEqual(Set(Hexagram.all.map(\.bits)).count, 64)
        XCTAssertEqual(Hexagram.all.map { $0.upper.name + $0.lower.name }, pairs)
    }

    func testEveryInputChangesOnlyMovingPositionsAndMapsToKnownHexagrams() throws {
        for code in 0..<4096 {
            let numbers = (0..<6).map { 6 + ((code >> ($0 * 2)) & 3) }
            let reading = try Reading(numbers: numbers)
            XCTAssertTrue((1...64).contains(reading.original.number))
            XCTAssertTrue((1...64).contains(reading.changed.number))
            for line in reading.lines(dayStem: "癸") {
                XCTAssertEqual(line.yang != line.changedYang, line.moving)
            }
        }
    }
}
