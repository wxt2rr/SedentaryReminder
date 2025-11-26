import Foundation
import UserNotifications
import Combine
import SwiftUI

@MainActor
class AppState: ObservableObject {
    // MARK: - 基础配置 (持久化)
    @Published var isRunning: Bool = false { didSet { saveSettings(); handleRunningStateChange() } }
    @Published var mode: ReminderMode = .interval { didSet { saveSettings() } }
    @Published var intervalMinutes: Int = 60 { didSet { saveSettings() } }
    @Published var cronExpression: String = "*/60 * * * *" { didSet { saveSettings(); validateCron() } }
    
    // MARK: - 文案配置 (持久化)
    @Published var notificationTitle: String = "久坐提醒" { didSet { saveSettings() } }
    @Published var notificationBody: String = "已经过去一段时间了，起来活动一下，喝口水吧！💺☕️" { didSet { saveSettings() } }
    
    // MARK: - 作息时间配置 (持久化)
    @Published var isScheduleEnabled: Bool = false { didSet { saveSettings() } }
    @Published var workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 30))! { didSet { saveSettings() } }
    @Published var workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 30))! { didSet { saveSettings() } }
    @Published var lunchStartTime: Date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))! { didSet { saveSettings() } }
    @Published var lunchEndTime: Date = Calendar.current.date(from: DateComponents(hour: 14, minute: 0))! { didSet { saveSettings() } }
    
    // MARK: - 提醒方式配置 (持久化)
    // 新增: 标准通知开关 (默认开启)
    @Published var isStandardNotificationEnabled: Bool = true { didSet { saveSettings() } }
    @Published var isPopupEnabled: Bool = true { didSet { saveSettings() } }
    @Published var isFullScreenEnabled: Bool = false { didSet { saveSettings() } }
    
    // MARK: - 运行时状态 (不持久化)
    @Published var showPopupAlert: Bool = false
    @Published var showFullScreenAlert: Bool = false
    
    let defaultIconName = "figure.seated.side.air.distribution.upper"
    let alertIconName = "figure.walk"
    @Published var currentIcon: String = "figure.seated.side.air.distribution.upper"
    
    @Published var nextRunDate: Date? = nil
    @Published var cronIsValid: Bool = true
    
    private var timer: Timer?
    
    enum ReminderMode: Int, Codable {
        case interval = 0
        case cron = 1
    }
    
    init() {
        loadSettings()
        requestNotificationPermission()
        validateCron()
        currentIcon = defaultIconName
        if isRunning { handleRunningStateChange() }
    }
    
    // MARK: - 逻辑控制
    func validateCron() {
        let test = CronParser.getNextRunDate(cronString: cronExpression)
        cronIsValid = (test != nil)
        if isRunning && mode == .cron && cronIsValid { scheduleNextCron() }
    }
    
    private func handleRunningStateChange() {
        timer?.invalidate()
        timer = nil
        nextRunDate = nil
        
        if isRunning {
            currentIcon = defaultIconName
            if mode == .interval { startIntervalTimer() }
            else { startCronTimer() }
        }
    }
    
    private func startIntervalTimer() {
        guard intervalMinutes > 0 else { return }
        nextRunDate = Date().addingTimeInterval(TimeInterval(intervalMinutes * 60))
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            self?.triggerReminder()
            self?.nextRunDate = Date().addingTimeInterval(TimeInterval((self?.intervalMinutes ?? 60) * 60))
        }
    }
    
    private func startCronTimer() { scheduleNextCron() }
    
    private func scheduleNextCron() {
        guard let nextDate = CronParser.getNextRunDate(cronString: cronExpression) else {
            isRunning = false
            return
        }
        self.nextRunDate = nextDate
        let interval = nextDate.timeIntervalSince(Date())
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.triggerReminder()
            self?.scheduleNextCron()
        }
    }
    
    // 核心触发逻辑
    private func triggerReminder() {
        if isScheduleEnabled && !shouldNotifyNow() {
            print("当前不在工作时间或处于午休期间，静默跳过。")
            return
        }
        
        // 1. 基础提醒 (通知中心) - 增加开关检查
        if isStandardNotificationEnabled {
            sendNotification()
        }
        
        // 图标动画总是播放 (作为最基础的视觉反馈)
        playIconAnimation()
        
        // 2. 强力提醒 (覆盖层)
        if isPopupEnabled {
            showPopupAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.showPopupAlert = false
            }
        }
        
        if isFullScreenEnabled {
            showFullScreenAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                if self?.showFullScreenAlert == true {
                    self?.showFullScreenAlert = false
                }
            }
        }
    }
    
    private func shouldNotifyNow() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let nowMins = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        func getMins(_ d: Date) -> Int {
            let c = calendar.dateComponents([.hour, .minute], from: d)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        let wStart = getMins(workStartTime); let wEnd = getMins(workEndTime)
        let lStart = getMins(lunchStartTime); let lEnd = getMins(lunchEndTime)
        
        var isInWork = false
        if wStart < wEnd { isInWork = (nowMins >= wStart && nowMins < wEnd) }
        else { isInWork = (nowMins >= wStart || nowMins < wEnd) }
        if !isInWork { return false }
        
        var isInLunch = false
        if lStart < lEnd { isInLunch = (nowMins >= lStart && nowMins < lEnd) }
        else { isInLunch = (nowMins >= lStart || nowMins < lEnd) }
        if isInLunch { return false }
        
        return true
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle.isEmpty ? "久坐提醒" : notificationTitle
        content.body = notificationBody.isEmpty ? "该起来活动啦！" : notificationBody
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func playIconAnimation() {
        func animate(count: Int) {
            guard count > 0 else { self.currentIcon = self.defaultIconName; return }
            if self.currentIcon == self.defaultIconName { self.currentIcon = self.alertIconName }
            else { self.currentIcon = self.defaultIconName }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animate(count: count - 1) }
        }
        animate(count: 10)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    // MARK: - Persistence
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isRunning, forKey: "isRunning")
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(intervalMinutes, forKey: "intervalMinutes")
        defaults.set(cronExpression, forKey: "cronExpression")
        defaults.set(notificationTitle, forKey: "notificationTitle")
        defaults.set(notificationBody, forKey: "notificationBody")
        defaults.set(isScheduleEnabled, forKey: "isScheduleEnabled")
        defaults.set(workStartTime.timeIntervalSince1970, forKey: "workStartTime")
        defaults.set(workEndTime.timeIntervalSince1970, forKey: "workEndTime")
        defaults.set(lunchStartTime.timeIntervalSince1970, forKey: "lunchStartTime")
        defaults.set(lunchEndTime.timeIntervalSince1970, forKey: "lunchEndTime")
        // 保存提醒方式设置
        defaults.set(isStandardNotificationEnabled, forKey: "isStandardNotificationEnabled")
        defaults.set(isPopupEnabled, forKey: "isPopupEnabled")
        defaults.set(isFullScreenEnabled, forKey: "isFullScreenEnabled")
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isRunning = defaults.bool(forKey: "isRunning")
        if let savedMode = ReminderMode(rawValue: defaults.integer(forKey: "mode")) { mode = savedMode }
        let savedInterval = defaults.integer(forKey: "intervalMinutes")
        if savedInterval > 0 { intervalMinutes = savedInterval }
        if let savedCron = defaults.string(forKey: "cronExpression") { cronExpression = savedCron }
        if let savedTitle = defaults.string(forKey: "notificationTitle") { notificationTitle = savedTitle }
        if let savedBody = defaults.string(forKey: "notificationBody") { notificationBody = savedBody }
        
        isScheduleEnabled = defaults.bool(forKey: "isScheduleEnabled")
        let wStart = defaults.double(forKey: "workStartTime")
        if wStart > 0 { workStartTime = Date(timeIntervalSince1970: wStart) }
        let wEnd = defaults.double(forKey: "workEndTime")
        if wEnd > 0 { workEndTime = Date(timeIntervalSince1970: wEnd) }
        let lStart = defaults.double(forKey: "lunchStartTime")
        if lStart > 0 { lunchStartTime = Date(timeIntervalSince1970: lStart) }
        let lEnd = defaults.double(forKey: "lunchEndTime")
        if lEnd > 0 { lunchEndTime = Date(timeIntervalSince1970: lEnd) }
        
        // 读取提醒方式设置 (注意处理首次运行默认值)
        if defaults.object(forKey: "isStandardNotificationEnabled") != nil {
            isStandardNotificationEnabled = defaults.bool(forKey: "isStandardNotificationEnabled")
        }
        if defaults.object(forKey: "isPopupEnabled") != nil {
             isPopupEnabled = defaults.bool(forKey: "isPopupEnabled")
        }
        isFullScreenEnabled = defaults.bool(forKey: "isFullScreenEnabled")
    }
}
