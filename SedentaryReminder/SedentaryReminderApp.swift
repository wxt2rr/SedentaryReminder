import SwiftUI

@main
struct SedentaryReminderApp: App {
    @StateObject private var appState = AppState()
    // 持有窗口管理器，确保它在 App 生命周期内一直存在
    @StateObject private var overlayManager: OverlayWindowManager
    
    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        // 使用同一个 appState 初始化管理器
        _overlayManager = StateObject(wrappedValue: OverlayWindowManager(appState: state))
    }
    
    var body: some Scene {
        MenuBarExtra("久坐提醒", systemImage: appState.currentIcon) {
            SettingsView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
