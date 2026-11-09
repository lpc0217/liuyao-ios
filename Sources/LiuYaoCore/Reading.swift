import Foundation

public struct Reading: Sendable {
    public let numbers: [Int]
    public let original: Hexagram
    public let changed: Hexagram
    public var originalName: String { original.name }
    public var changedName: String { changed.name }
    public var movingPositions: [Int] { numbers.indices.filter { numbers[$0] == 6 || numbers[$0] == 9 }.map { $0 + 1 } }

    public init(numbers: [Int]) throws {
        guard numbers.count == 6, numbers.allSatisfy({ (6...9).contains($0) }) else {
            throw ReadingError.invalidNumbers
        }
        self.numbers = numbers
        let originalBits = numbers.enumerated().reduce(0) { $0 | (($1.element % 2) << $1.offset) }
        let changedBits = numbers.enumerated().reduce(0) { value, item in
            value | ((item.element == 6 || item.element == 7 ? 1 : 0) << item.offset)
        }
        original = Hexagram.at(bits: originalBits)
        changed = Hexagram.at(bits: changedBits)
    }

    public func lines(dayStem: String) -> [ChartLine] {
        let gods = ["青龙", "朱雀", "勾陈", "螣蛇", "白虎", "玄武"]
        let start = ["甲": 0, "乙": 0, "丙": 1, "丁": 1, "戊": 2, "己": 3, "庚": 4, "辛": 4, "壬": 5, "癸": 5][dayStem] ?? 0
        return numbers.indices.map { index in
            // 变爻六亲仍以本卦宫五行为参照。
            let branch = original.branches[index]
            let changedBranch = changed.branches[index]
            return ChartLine(position: index + 1, number: numbers[index],
                             stemBranch: original.stems[index] + branch.name,
                             element: branch.element, relative: branch.element.relative(to: original.palace.element),
                             god: gods[(start + index) % 6],
                             isSelf: index + 1 == original.selfPosition,
                             isOther: index + 1 == original.otherPosition,
                             changedStemBranch: changed.stems[index] + changedBranch.name,
                             changedElement: changedBranch.element,
                             changedRelative: changedBranch.element.relative(to: original.palace.element))
        }
    }
}

public enum ReadingError: LocalizedError {
    case invalidNumbers
    public var errorDescription: String? { "请按初爻到上爻输入六个数字，每个数字只能是 6、7、8、9。" }
}

public struct ChartLine: Identifiable {
    public let position: Int
    public let number: Int
    public let stemBranch: String
    public let element: Element
    public let relative: String
    public let god: String
    public let isSelf: Bool
    public let isOther: Bool
    public let changedStemBranch: String
    public let changedElement: Element
    public let changedRelative: String
    public var id: Int { position }
    public var yang: Bool { number % 2 == 1 }
    public var moving: Bool { number == 6 || number == 9 }
    public var changedYang: Bool { number == 6 || number == 7 }
    public var label: String { ["初爻", "二爻", "三爻", "四爻", "五爻", "上爻"][position - 1] }
    public var kind: String { [6: "老阴", 7: "少阳", 8: "少阴", 9: "老阳"][number]! }
}
