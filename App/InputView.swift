import SwiftUI
import LiuYaoCore

struct InputView: View {
    @EnvironmentObject private var store: AppStore
    @State private var question = ""
    @State private var numbers = Array<Int?>(repeating: nil, count: 6)
    @State private var date = Date()
    @State private var timeZoneID = TimeZone.current.identifier
    @State private var result: ReadingRecord?
    @State private var error: String?
    @FocusState private var focused: Bool
    private var complete: Bool { numbers.allSatisfy { $0 != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("六爻").font(Theme.title)
                    Text("一事一问，依次记下六次爻数。")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }.padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Text("此刻想问什么").font(.headline)
                    TextField("例如：近期这次工作调动该如何看待？", text: $question, axis: .vertical)
                        .lineLimit(2...4).padding(14).background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))
                        .focused($focused).accessibilityIdentifier("question")
                        .onChange(of: question) { _, new in if new.count > 2000 { question = String(new.prefix(2000)) } }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "记下六爻", note: "已选 \(numbers.compactMap { $0 }.count) / 6")
                    Text("从初爻开始选；排盘时初爻会显示在最下方。")
                        .font(.caption).foregroundStyle(Theme.muted)
                    ForEach(0..<6) { index in
                        HStack(spacing: 12) {
                            Text(["初爻","二爻","三爻","四爻","五爻","上爻"][index])
                                .font(.subheadline.weight(.medium)).frame(width: 38)
                            HStack(spacing: 6) {
                                ForEach(6...9, id: \.self) { number in
                                    Button {
                                        focused = false
                                        numbers[index] = number
                                    } label: {
                                        Text(String(number)).font(.body.weight(numbers[index] == number ? .bold : .regular))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .foregroundStyle(numbers[index] == number ? Theme.onAccent : Theme.ink)
                                            .background(numbers[index] == number ? Theme.accent : Theme.sheet, in: RoundedRectangle(cornerRadius: 8))
                                    }.buttonStyle(.plain)
                                        .accessibilityLabel("\(["初爻","二爻","三爻","四爻","五爻","上爻"][index])，\(number)，\([6:"老阴",7:"少阳",8:"少阴",9:"老阳"][number]!)")
                                        .accessibilityAddTraits(numbers[index] == number ? .isSelected : [])
                                        .accessibilityIdentifier("line-\(index)-\(number)")
                                }
                            }
                        }
                    }
                    HStack { Text("6 老阴　7 少阳　8 少阴　9 老阳"); Spacer() }
                        .font(.caption).foregroundStyle(Theme.muted)
                    Text("6、9 为动爻，变卦时阴阳互换。")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                DisclosureGroup("起卦时间与时区") {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("实际摇卦时间", selection: $date, in: supportedDates, displayedComponents: [.date, .hourAndMinute])
                            .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
                        Picker("起卦地时区", selection: $timeZoneID) {
                            ForEach(timeZones, id: \.self) { zone in Text(zone).tag(zone) }
                        }
                        Text(CalendarContext.convention).font(.caption).foregroundStyle(Theme.muted)
                    }.padding(.top, 12)
                }.font(.subheadline)
                if let error { Text(error).font(.subheadline).foregroundStyle(Theme.accent) }
                Button("查看排盘") { createReading() }
                    .buttonStyle(PrimaryButton()).disabled(!complete)
                    .accessibilityIdentifier("create-reading")
                HStack {
                    Button("填入示例") { question = "近期这次工作调动该如何看待？"; numbers = [7,7,8,9,8,7] }
                        .accessibilityIdentifier("fill-example")
                    Spacer()
                    Button("清空爻数") { numbers = Array(repeating: nil, count: 6) }
                }.font(.subheadline).padding(.bottom, 20)
            }.padding(.horizontal, 24)
        }
        .background(Theme.paper).foregroundStyle(Theme.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focused = false } } }
        .navigationDestination(item: $result) { record in ReadingDetailView(record: record) }
        #if DEBUG
        .onReceive(store.$verificationRecord) { if let record = $0 { result = record } }
        #endif
    }

    private var timeZones: [String] { Array(Set([TimeZone.current.identifier, "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Taipei", "America/Toronto", "America/Vancouver", "America/New_York", "Europe/London", "UTC"])).sorted() }
    private var supportedDates: ClosedRange<Date> {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: "1901-01-02T00:00:00Z")!...formatter.date(from: "2099-12-30T00:00:00Z")!
    }
    private func createReading() {
        do {
            _ = try Reading(numbers: numbers.compactMap { $0 })
            _ = try CalendarContext(date: date, timeZoneID: timeZoneID)
            let record = ReadingRecord(question: question.trimmingCharacters(in: .whitespacesAndNewlines), numbers: numbers.compactMap { $0 }, date: date, timeZoneID: timeZoneID)
            guard store.add(record) else { return }
            focused = false
            result = record
        } catch { self.error = error.localizedDescription }
    }
}

extension ReadingRecord: Hashable {
    static func == (lhs: ReadingRecord, rhs: ReadingRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
