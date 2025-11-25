import Foundation

struct CronParser {
    
    // 标准 Cron 格式：分 时 日 月 周
    // 示例：30 * * * * (每小时的第30分)
    // 示例：*/15 * * * * (每15分钟)
    
    static func getNextRunDate(cronString: String, from date: Date = Date()) -> Date? {
        let parts = cronString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard parts.count == 5 else { return nil }
        
        let calendar = Calendar.current
        // 从当前时间的下一分钟开始找，避免重复触发
        var candidateDate = calendar.date(byAdding: .minute, value: 1, to: date)!
        candidateDate = calendar.date(bySetting: .second, value: 0, of: candidateDate) ?? candidateDate
        
        // 限制向后查找 1 年
        let maxDate = calendar.date(byAdding: .year, value: 1, to: date)!
        
        while candidateDate < maxDate {
            if matches(parts: parts, date: candidateDate, calendar: calendar) {
                return candidateDate
            }
            candidateDate = calendar.date(byAdding: .minute, value: 1, to: candidateDate)!
        }
        
        return nil
    }
    
    private static func matches(parts: [String], date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        
        guard let minute = components.minute,
              let hour = components.hour,
              let day = components.day,
              let month = components.month,
              let weekday = components.weekday else { return false }
        
        if !checkPart(parts[0], value: minute, min: 0, max: 59) { return false }
        if !checkPart(parts[1], value: hour, min: 0, max: 23) { return false }
        if !checkPart(parts[2], value: day, min: 1, max: 31) { return false }
        if !checkPart(parts[3], value: month, min: 1, max: 12) { return false }
        
        // Cron Weekday: 0-6 (Sun-Sat), Calendar: 1-7. Convert to 0-6.
        let cronWeekday = (weekday - 1)
        if !checkPart(parts[4], value: cronWeekday, min: 0, max: 6) { return false }
        
        return true
    }
    
    private static func checkPart(_ part: String, value: Int, min: Int, max: Int) -> Bool {
        if part == "*" { return true }
        
        if part.contains("/") {
            let subParts = part.components(separatedBy: "/")
            if subParts.count == 2, let step = Int(subParts[1]) {
                if subParts[0] == "*" {
                    return (value - min) % step == 0
                } else if let start = Int(subParts[0]) {
                     return value >= start && (value - start) % step == 0
                }
            }
        }
        
        if part.contains(",") {
            let list = part.components(separatedBy: ",").compactMap { Int($0) }
            return list.contains(value)
        }
        
        if part.contains("-") {
            let subParts = part.components(separatedBy: "-")
            if subParts.count == 2, let start = Int(subParts[0]), let end = Int(subParts[1]) {
                return value >= start && value <= end
            }
        }
        
        if let intVal = Int(part) {
            return intVal == value
        }
        
        return false
    }
}
