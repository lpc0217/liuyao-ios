import Foundation

public enum Element: String, CaseIterable, Codable, Sendable {
    case wood = "木", fire = "火", earth = "土", metal = "金", water = "水"

    public func relative(to palace: Element) -> String {
        let cycle: [Element] = [.wood, .fire, .earth, .metal, .water]
        let mine = cycle.firstIndex(of: palace)!
        let theirs = cycle.firstIndex(of: self)!
        switch (theirs - mine + 5) % 5 {
        case 0: return "兄弟"
        case 1: return "子孙"
        case 2: return "妻财"
        case 3: return "官鬼"
        default: return "父母"
        }
    }
}

public struct Branch: Sendable {
    public let name: String
    public let element: Element
    static let all: [Branch] = zip(Array("子丑寅卯辰巳午未申酉戌亥").map(String.init),
                                    [Element.water, .earth, .wood, .wood, .earth, .fire, .fire, .earth, .metal, .metal, .earth, .water])
        .map { Branch(name: $0.0, element: $0.1) }
}

public struct Trigram: Identifiable, Sendable {
    public let bits: Int
    public let name: String
    public let imageName: String
    public let element: Element
    let innerBranches: [Int]
    let outerBranches: [Int]
    let innerStem: String
    let outerStem: String
    public var id: Int { bits }
    public var symbol: String { ["☷", "☳", "☵", "☱", "☶", "☲", "☴", "☰"][bits] }

    // 三位二进制从低位到高位对应初、二、三爻。
    public static let all: [Trigram] = [
        .init(bits: 0, name: "坤", imageName: "地", element: .earth, innerBranches: [7,5,3], outerBranches: [1,11,9], innerStem: "乙", outerStem: "癸"),
        .init(bits: 1, name: "震", imageName: "雷", element: .wood, innerBranches: [0,2,4], outerBranches: [6,8,10], innerStem: "庚", outerStem: "庚"),
        .init(bits: 2, name: "坎", imageName: "水", element: .water, innerBranches: [2,4,6], outerBranches: [8,10,0], innerStem: "戊", outerStem: "戊"),
        .init(bits: 3, name: "兑", imageName: "泽", element: .metal, innerBranches: [5,3,1], outerBranches: [11,9,7], innerStem: "丁", outerStem: "丁"),
        .init(bits: 4, name: "艮", imageName: "山", element: .earth, innerBranches: [4,6,8], outerBranches: [10,0,2], innerStem: "丙", outerStem: "丙"),
        .init(bits: 5, name: "离", imageName: "火", element: .fire, innerBranches: [3,1,11], outerBranches: [9,7,5], innerStem: "己", outerStem: "己"),
        .init(bits: 6, name: "巽", imageName: "风", element: .wood, innerBranches: [1,11,9], outerBranches: [7,5,3], innerStem: "辛", outerStem: "辛"),
        .init(bits: 7, name: "乾", imageName: "天", element: .metal, innerBranches: [0,2,4], outerBranches: [6,8,10], innerStem: "甲", outerStem: "壬")
    ]
}

public struct Hexagram: Identifiable, Sendable {
    public let bits: Int
    public let number: Int
    public let shortName: String
    public let palaceBits: Int
    public let palaceIndex: Int
    public var id: Int { number }
    public var upper: Trigram { Trigram.all[bits >> 3] }
    public var lower: Trigram { Trigram.all[bits & 7] }
    public var palace: Trigram { Trigram.all[palaceBits] }
    public var name: String {
        upper.bits == lower.bits ? "\(upper.name)为\(upper.imageName)" : "\(upper.imageName)\(lower.imageName)\(shortName)"
    }
    public var symbol: String { String(UnicodeScalar(0x4DC0 + number - 1)!) }
    public var stage: String { ["本宫", "一世", "二世", "三世", "四世", "五世", "游魂", "归魂"][palaceIndex] }
    public var selfPosition: Int { [6,1,2,3,4,5,4,3][palaceIndex] }
    public var otherPosition: Int { (selfPosition + 2) % 6 + 1 }
    public var branches: [Branch] { (lower.innerBranches + upper.outerBranches).map { Branch.all[$0] } }
    public var stems: [String] { Array(repeating: lower.innerStem, count: 3) + Array(repeating: upper.outerStem, count: 3) }
    public var meaning: String { Self.meanings[number - 1] }

    public static func at(bits: Int) -> Hexagram {
        precondition((0..<64).contains(bits))
        return all.first { $0.bits == bits }!
    }

    public static let all: [Hexagram] = {
        let palaces: [(Int, [String], [Int])] = [
            (7, ["乾","姤","遁","否","观","剥","晋","大有"], [1,44,33,12,20,23,35,14]),
            (3, ["兑","困","萃","咸","蹇","谦","小过","归妹"], [58,47,45,31,39,15,62,54]),
            (5, ["离","旅","鼎","未济","蒙","涣","讼","同人"], [30,56,50,64,4,59,6,13]),
            (1, ["震","豫","解","恒","升","井","大过","随"], [51,16,40,32,46,48,28,17]),
            (6, ["巽","小畜","家人","益","无妄","噬嗑","颐","蛊"], [57,9,37,42,25,21,27,18]),
            (2, ["坎","节","屯","既济","革","丰","明夷","师"], [29,60,3,63,49,55,36,7]),
            (4, ["艮","贲","大畜","损","睽","履","中孚","渐"], [52,22,26,41,38,10,61,53]),
            (0, ["坤","复","临","泰","大壮","夬","需","比"], [2,24,19,11,34,43,5,8])
        ]
        let masks = [0,1,3,7,15,31,23,16]
        return palaces.flatMap { palace, names, numbers in
            names.indices.map { index in
                Hexagram(bits: (palace | (palace << 3)) ^ masks[index], number: numbers[index],
                         shortName: names[index], palaceBits: palace, palaceIndex: index)
            }
        }.sorted { $0.number < $1.number }
    }()

    // 独立编写的简明卦意，仅作卦象阅读提示，不是对具体事项的预测。
    static let meanings = [
        "刚健进取，也要察时守度，避免用力过满。", "厚德承载，以柔顺和持续行动积累力量。",
        "起步多有阻力，先建立秩序，再寻求助力。", "面对未知先求教，明确问题比急于求成更重要。",
        "条件未齐时耐心准备，等待不是停止行动。", "分歧宜先协商，辨清事实，避免争执升级。",
        "组织行动重在纪律、公正与合适的带领者。", "合作需要互信，先辨明共同目标与责任。",
        "积蓄尚小，以细节和克制逐步创造条件。", "处境需谨慎，守住分寸，尊重规则。",
        "沟通顺畅时推进合作，同时为变化留有余地。", "沟通受阻时收敛行动，先修复内部基础。",
        "以共同原则凝聚伙伴，避免只顾小圈子。", "资源充足时保持谦逊，把能力用于合适之处。",
        "降低姿态、承认不足，稳健比争先更有力量。", "行动前做好准备，以节奏和共识带动参与。",
        "顺应合适的变化，同时保留自己的判断。", "旧问题需要整治，先找根源，再落实责任。",
        "接近目标时主动投入，也要警惕后续变化。", "先观察整体与自身，再决定如何介入。",
        "阻碍需明确处理，依据事实和规则解决问题。", "形式可以增色，但不能替代内容与实力。",
        "基础受损时宜保全，减少冒进，等待转机。", "回到正确方向，从小而持续的行动重新开始。",
        "守住真实与本分，避免侥幸和不切实际的期待。", "积累能力与资源，克制冲动，等待承担大事。",
        "留意所吸收与付出的东西，言语和习惯都需节制。", "负荷超过常态，需调整结构并寻求支撑。",
        "反复遇险时保持清醒，以可信步骤逐段通过。", "依托清晰的原则与支持，让判断保持明亮。",
        "互动从感受开始，真诚回应，避免强求。", "长期关系和事业依靠稳定原则与持续修正。",
        "条件不利时适度退让，保留空间与主动权。", "力量增强时更需守正，避免把强势当优势。",
        "有机会向前发展，以清楚的贡献赢得信任。", "才华暂时难展，保护自己，谨慎表达。",
        "内部秩序来自角色清楚、相互尊重与日常落实。", "差异客观存在，从小处寻找可合作的部分。",
        "前路艰难时暂停硬闯，反思路线并寻求帮助。", "压力缓解后及时处理遗留问题，恢复行动。",
        "适度减少眼前消耗，把资源留给真正重要之事。", "增加助力也要落实行动，成长来自互相成就。",
        "需要作出决断时，公开表达事实，避免逞强。", "突如其来的接触要辨明性质，不轻易投入。",
        "聚合人力与资源，关键在共同目标和组织秩序。", "由小处逐步向上，扎实积累比急求结果可靠。",
        "资源受限时守住内在原则，寻找可行的小出口。", "维护长久有用的基础，让资源真正发挥作用。",
        "改变旧方式需合适时机、充分理由和共同信任。", "更新承载事物的结构，使能力与责任相匹配。",
        "变化或震动到来时先稳住自己，再恢复秩序。", "知道何时停止，守住位置，让身心重新安定。",
        "循序推进，给关系和成果足够的成熟时间。", "位置或条件不够对等时，谨慎承诺与行动。",
        "局面充盛时保持清醒，及时安排后续与交接。", "身处陌生环境宜谦谨，守规则，少作过度依赖。",
        "以温和而持续的方式推进，清楚表达并反复落实。", "交流带来愉悦，真诚和分寸让关系更长久。",
        "隔阂需要化解，以共同目标重新连接分散力量。", "建立适当限制，规则应可执行，也留有弹性。",
        "信任从内在诚实和一致行动产生，不靠表面说服。", "重视细小偏差，谨慎处理眼前可控的事情。",
        "事情初成仍需维护，留意细节与后续风险。", "尚未完成时保持耐心，调整配合，谨慎走好最后一步。"
    ]
}
