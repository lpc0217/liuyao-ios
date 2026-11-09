import SwiftUI
import LiuYaoCore

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var deleteID: UUID?
    private var filtered: [ReadingRecord] {
        store.records.filter { record in
            search.isEmpty || record.question.localizedCaseInsensitiveContains(search) ||
            ((try? Reading(numbers: record.numbers).original.name.localizedCaseInsensitiveContains(search)) ?? false)
        }
    }
    var body: some View {
        Group {
            if store.records.isEmpty {
                ContentUnavailableView("还没有卦记", systemImage: "clock", description: Text("在「起卦」页完成一次排盘，就会保存在这里。"))
            } else {
                List {
                    ForEach(filtered) { record in
                        NavigationLink { ReadingDetailView(record: record) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(record.question.isEmpty ? "此卦无题" : record.question).font(.headline).lineLimit(2)
                                if let reading = try? Reading(numbers: record.numbers) {
                                    Text(reading.original.name + (reading.movingPositions.isEmpty ? "（静卦）" : " → " + reading.changed.name))
                                        .font(.subheadline).foregroundStyle(Theme.accent)
                                }
                                Text("\((try? CalendarContext(date: record.date, timeZoneID: record.timeZoneID).localDate) ?? "")\n\(record.timeZoneID)　\(record.messages.isEmpty ? "待解读" : "已解读")")
                                    .font(.caption).foregroundStyle(Theme.muted)
                            }.padding(.vertical, 6)
                        }.listRowBackground(Theme.sheet)
                            .swipeActions { Button("删除", role: .destructive) { deleteID = record.id } }
                    }
                }.searchable(text: $search, prompt: "搜索事项或本卦")
                    .overlay { if filtered.isEmpty { ContentUnavailableView.search(text: search) } }
                    .scrollContentBackground(.hidden)
            }
        }.background(Theme.paper).foregroundStyle(Theme.ink).navigationTitle("卦记")
            .confirmationDialog("删除这条卦记？", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } }), titleVisibility: .visible) {
                Button("删除卦记", role: .destructive) { if let id = deleteID { store.delete(id) }; deleteID = nil }
            }
    }
}
