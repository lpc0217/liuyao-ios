import Foundation
import LunarSwift

public struct CalendarContext {
    public let year: String
    public let month: String
    public let day: String
    public let voidBranches: String
    public let localDate: String
    public let timeZoneID: String
    public var dayStem: String { String(day.prefix(1)) }
    public static let convention = "月柱按北京时间节气交节；日柱按所选时区零点换日，不校正真太阳时。"

    public init(date: Date, timeZoneID: String) throws {
        guard let zone = TimeZone(identifier: timeZoneID) else { throw CalendarError.invalidTimeZone }
        var local = Calendar(identifier: .gregorian)
        local.timeZone = zone
        let parts = local.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              (1901...2099).contains(year) else { throw CalendarError.unsupportedYear }
        // 节气库使用东八区天文时刻，先把真实时刻转换到北京时间，避免多伦多等时区交节偏差。
        var beijing = Calendar(identifier: .gregorian)
        beijing.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let bj = beijing.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
        let seasonal = Solar(year: bj.year!, month: bj.month!, day: bj.day!, hour: bj.hour!, minute: bj.minute!, second: bj.second!).lunar
        let daily = Solar(year: year, month: month, day: day, hour: 12).lunar
        self.year = seasonal.yearInGanZhiExact
        self.month = seasonal.monthInGanZhiExact
        self.day = daily.dayInGanZhi
        voidBranches = daily.dayXunKong
        self.timeZoneID = timeZoneID
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        localDate = formatter.string(from: date)
    }
}

public enum CalendarError: LocalizedError {
    case invalidTimeZone, unsupportedYear
    public var errorDescription: String? {
        switch self {
        case .invalidTimeZone: return "无法识别时区，请重新选择。"
        case .unsupportedYear: return "目前支持 1901 至 2099 年的起卦时间。"
        }
    }
}
