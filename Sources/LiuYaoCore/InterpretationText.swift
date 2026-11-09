import Foundation

public struct InterpretationText {
    public let summary: String?
    public let details: String

    public init(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        let headingMarks = CharacterSet(charactersIn: "#* ：:\t")
        if let heading = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[heading].trimmingCharacters(in: headingMarks) == "一句话总结",
           let sentence = lines.indices.first(where: { $0 > heading && !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty }),
           !lines[sentence].trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            summary = lines[sentence].trimmingCharacters(in: CharacterSet(charactersIn: "* \t"))
            details = lines.dropFirst(sentence + 1).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // 兼容旧卦记或未遵循格式的回答，保留完整原文。
            summary = nil
            details = content
        }
    }
}
