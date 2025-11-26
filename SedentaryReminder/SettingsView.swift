import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showPreferences = false
    @State private var selectedTab: PreferenceTab = .general
    
    enum PreferenceTab: String, CaseIterable {
        case general = "通用"
        case schedule = "作息"
        case behavior = "行为"
        var iconName: String {
            switch self {
            case .general: return "timer"
            case .schedule: return "clock"
            case .behavior: return "bell.badge"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
            if showPreferences {
                ModernPreferencesView(appState: appState, showPreferences: $showPreferences, selectedTab: $selectedTab)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                DashboardView(appState: appState, showPreferences: $showPreferences)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 380, height: 480)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showPreferences)
    }
}

// MARK: - 视图 1：主仪表盘 (保持不变)
struct DashboardView: View {
    @ObservedObject var appState: AppState
    @Binding var showPreferences: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { showPreferences = true }) {
                    Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundColor(.secondary)
                }.buttonStyle(.plain).help("偏好设置")
            }.padding([.top, .trailing], 24)
            
            Spacer()
            
            ZStack {
                Circle().stroke(lineWidth: 6).foregroundColor(appState.isRunning ? .accentColor.opacity(0.2) : .gray.opacity(0.1)).frame(width: 140, height: 140)
                VStack(spacing: 10) {
                    Image(systemName: appState.currentIcon).font(.system(size: 48)).foregroundColor(appState.isRunning ? .accentColor : .gray).symbolEffect(.bounce, value: appState.currentIcon)
                    if appState.isRunning {
                        if let nextDate = appState.nextRunDate { VStack(spacing: 4) { Text("下一次提醒").font(.footnote).foregroundColor(.secondary); Text(nextDate, style: .time).font(.system(.title, design: .rounded).bold()).foregroundColor(.primary) } }
                    } else { Text("已暂停").font(.title3).fontWeight(.medium).foregroundColor(.secondary) }
                }
            }
            
            Spacer()
            
            Button(action: { withAnimation { appState.isRunning.toggle() } }) {
                Text(appState.isRunning ? "停止" : "开始专注").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16).background(appState.isRunning ? Color.red.opacity(0.1) : Color.accentColor).foregroundColor(appState.isRunning ? .red : .white).cornerRadius(16)
            }.buttonStyle(.plain).padding(.horizontal, 32).padding(.bottom, 32)
        }
    }
}

// MARK: - 视图 2：全新的偏好设置页 (保持不变)
struct ModernPreferencesView: View {
    @ObservedObject var appState: AppState
    @Binding var showPreferences: Bool
    @Binding var selectedTab: SettingsView.PreferenceTab
    @Namespace private var tabNamespace
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { showPreferences = false }) { HStack(spacing: 6) { Image(systemName: "chevron.backward").fontWeight(.semibold); Text("返回").fontWeight(.medium) } }.buttonStyle(.plain).foregroundColor(.accentColor)
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) { Image(systemName: "power").fontWeight(.medium).foregroundColor(.red.opacity(0.8)) }.buttonStyle(.plain).help("退出应用程序")
            }.padding(.horizontal, 20).padding(.vertical, 16)
            
            HStack(spacing: 0) {
                ForEach(SettingsView.PreferenceTab.allCases, id: \.self) { tab in
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab } } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) { Image(systemName: tab.iconName); Text(tab.rawValue) }.font(.system(size: 14, weight: .medium)).foregroundColor(selectedTab == tab ? .primary : .secondary)
                            if selectedTab == tab { Color.accentColor.frame(height: 3).matchedGeometryEffect(id: "tab_indicator", in: tabNamespace) } else { Color.clear.frame(height: 3) }
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20).padding(.bottom, 10)
            Divider()
            
            ScrollView {
                VStack(spacing: 32) {
                    switch selectedTab {
                    case .general: ModernGeneralPrefs(appState: appState)
                    case .schedule: ModernSchedulePrefs(appState: appState)
                    case .behavior: ModernBehaviorPrefs(appState: appState)
                    }
                }.padding(24)
            }
        }.background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 通用设置组件 (保持不变)
struct ModernGeneralPrefs: View {
    @ObservedObject var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Label("触发模式", systemImage: "arrow.triangle.branch").font(.headline)
                Picker("", selection: $appState.mode) { Text("固定间隔").tag(AppState.ReminderMode.interval); Text("高级规则 (Cron)").tag(AppState.ReminderMode.cron) }.pickerStyle(.segmented).disabled(appState.isRunning)
            }
            Divider()
            if appState.mode == .interval {
                VStack(alignment: .leading, spacing: 12) {
                    Label("间隔时长", systemImage: "hourglass").font(.headline)
                    HStack(spacing: 12) {
                        TextField("60", value: $appState.intervalMinutes, formatter: NumberFormatter()).textFieldStyle(.plain).font(.system(.title2, design: .rounded).bold()).multilineTextAlignment(.center).frame(width: 80, height: 50).background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor))).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        Text("分钟提醒一次").font(.body).foregroundColor(.secondary)
                    }
                }.disabled(appState.isRunning)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Cron 表达式", systemImage: "terminal.fill").font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("*/60 * * * *", text: $appState.cronExpression).textFieldStyle(.plain).font(.system(.body, design: .monospaced)).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor))).overlay(RoundedRectangle(cornerRadius: 12).stroke(appState.cronIsValid ? Color.secondary.opacity(0.2) : Color.red.opacity(0.5), lineWidth: 1))
                        if !appState.cronIsValid { Label("表达式格式无效", systemImage: "exclamationmark.triangle.fill").foregroundColor(.red).font(.caption) }
                        Text("示例: \"0 * * * *\" (每小时整点)").font(.caption).foregroundColor(.secondary)
                    }
                }.disabled(appState.isRunning)
            }
        }
    }
}

// MARK: - 作息设置组件 (保持不变)
struct ModernSchedulePrefs: View {
    @ObservedObject var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Label("作息限制", systemImage: "calendar.badge.clock").font(.headline); Text("仅在工作时间内运行，并跳过午休").font(.caption).foregroundColor(.secondary) }
                Spacer(); Toggle("", isOn: $appState.isScheduleEnabled).toggleStyle(.switch)
            }.padding(16).background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor)))
            if appState.isScheduleEnabled {
                VStack(spacing: 20) {
                    TimeRangePicker(icon: "briefcase.fill", title: "工作时段", start: $appState.workStartTime, end: $appState.workEndTime)
                    Divider()
                    TimeRangePicker(icon: "cup.and.saucer.fill", title: "午休屏蔽", start: $appState.lunchStartTime, end: $appState.lunchEndTime)
                }.padding(16).background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor)).opacity(0.5))
            }
        }
    }
}
struct TimeRangePicker: View {
    let icon: String; let title: String; @Binding var start: Date; @Binding var end: Date
    var body: some View { HStack { Label(title, systemImage: icon).font(.subheadline).fontWeight(.medium).foregroundColor(.secondary); Spacer(); HStack(spacing: 8) { DatePicker("", selection: $start, displayedComponents: .hourAndMinute).labelsHidden(); Text("至").foregroundColor(.secondary); DatePicker("", selection: $end, displayedComponents: .hourAndMinute).labelsHidden() } } }
}

// MARK: - 行为设置组件 (新增了标准通知开关)
struct ModernBehaviorPrefs: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            
            // 1. 通知文案区域 (保持不变)
            VStack(alignment: .leading, spacing: 16) {
                Label("通知文案", systemImage: "message.fill").font(.headline)
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("标题").font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
                        TextField("输入通知标题", text: $appState.notificationTitle).textFieldStyle(.plain).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor))).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("内容").font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
                        TextField("输入通知内容", text: $appState.notificationBody, axis: .vertical).textFieldStyle(.plain).padding(10).frame(minHeight: 80, alignment: .top).background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor))).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                }
            }
            
            Divider()
            
            // 2. 触达反馈区域 (更新：包含三种提醒方式)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    // 标题改得更通用
                    Label("触达反馈", systemImage: "bell.badge.fill")
                        .font(.headline)
                    Text("选择你希望接收提醒的方式组合")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    // 新增：标准通知开关
                    ToggleBox(title: "系统通知横幅", icon: "app.badge.fill", isOn: $appState.isStandardNotificationEnabled)
                    // 现有的强力提醒开关
                    ToggleBox(title: "屏幕中央弹窗", icon: "macwindow.on.rectangle", isOn: $appState.isPopupEnabled)
                    ToggleBox(title: "全屏强力遮罩", icon: "display.trianglebadge.exclamationmark", isOn: $appState.isFullScreenEnabled)
                }
            }
        }
    }
}

// 开关卡片组件 (保持不变)
struct ToggleBox: View {
    let title: String; let icon: String; @Binding var isOn: Bool
    var body: some View {
        HStack { Label(title, systemImage: icon).font(.body); Spacer(); Toggle("", isOn: $isOn).toggleStyle(.switch) }
            .padding(16).background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }
}
