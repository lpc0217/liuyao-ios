import SwiftUI

enum Theme {
    static let paper = Color(red: 0.97, green: 0.955, blue: 0.925)
    static let sheet = Color(red: 0.995, green: 0.985, blue: 0.96)
    static let ink = Color(red: 0.16, green: 0.18, blue: 0.17)
    static let muted = Color(red: 0.40, green: 0.41, blue: 0.38)
    static let rule = Color(red: 0.80, green: 0.79, blue: 0.74)
    static let accent = Color(red: 0.63, green: 0.19, blue: 0.14)
    static let onAccent = Color.white
    static let title = Font.system(.largeTitle, design: .serif).weight(.medium)
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct YaoMark: View {
    let yang: Bool
    var moving = false
    var body: some View {
        HStack(spacing: 8) {
            if yang {
                Rectangle().fill(moving ? Theme.accent : Theme.ink)
            } else {
                Rectangle().fill(moving ? Theme.accent : Theme.ink)
                Rectangle().fill(Theme.paper).frame(width: 12)
                Rectangle().fill(moving ? Theme.accent : Theme.ink)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(yang ? "阳爻" : "阴爻")\(moving ? "，动爻" : "")")
    }
}

struct SectionHeading: View {
    let title: String
    var note: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            Spacer()
            if let note { Text(note).font(.caption).foregroundStyle(Theme.muted) }
        }.padding(.top, 10)
    }
}
