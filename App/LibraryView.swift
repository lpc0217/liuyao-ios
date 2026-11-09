import SwiftUI
import LiuYaoCore

struct LibraryView: View {
    @State private var search = ""
    private var filtered: [Hexagram] {
        Hexagram.all.filter { search.isEmpty || $0.name.contains(search) || String($0.number) == search || $0.upper.name.contains(search) || $0.lower.name.contains(search) }
    }
    var body: some View {
        List(filtered) { hexagram in
            NavigationLink { HexagramInfoView(hexagram: hexagram) } label: {
                HStack(spacing: 16) {
                    Text(hexagram.symbol).font(.system(size: 38)).foregroundStyle(Theme.ink).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(hexagram.name).font(.headline)
                        Text("第\(hexagram.number)卦　上\(hexagram.upper.name)下\(hexagram.lower.name)")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }.padding(.vertical, 5)
            }.listRowBackground(Theme.sheet)
        }.searchable(text: $search, prompt: "搜索卦名、卦序或上下卦")
            .overlay { if filtered.isEmpty { ContentUnavailableView.search(text: search) } }
            .scrollContentBackground(.hidden).background(Theme.paper).foregroundStyle(Theme.ink).navigationTitle("六十四卦")
    }
}

struct HexagramInfoView: View {
    let hexagram: Hexagram
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HexagramPanel(hexagram: hexagram, label: "第\(hexagram.number)卦").padding(.top, 12)
                Divider().overlay(Theme.ink)
                SectionHeading(title: "卦意简读")
                Text(hexagram.meaning).font(.title3).lineSpacing(8).textSelection(.enabled)
                Text("\(hexagram.upper.name)为\(hexagram.upper.imageName)，在上；\(hexagram.lower.name)为\(hexagram.lower.imageName)，在下。")
                    .font(.body).foregroundStyle(Theme.muted)
                Text("\(hexagram.palace.name)宫属\(hexagram.palace.element.rawValue)，\(hexagram.stage)。世在第\(hexagram.selfPosition)爻，应在第\(hexagram.otherPosition)爻。")
                    .font(.body).foregroundStyle(Theme.muted)
                Text("卦意摘要为独立编写，便于离线查阅。具体事项需结合问题、动爻与日月阅读。")
                    .font(.caption).foregroundStyle(Theme.muted)
                Link("阅读六十四卦参考资料", destination: URL(string: "https://www.fatemaster.ai/guides/64-hexagrams")!)
            }.padding(24)
        }.background(Theme.paper).foregroundStyle(Theme.ink).navigationTitle(hexagram.shortName).navigationBarTitleDisplayMode(.inline)
    }
}
