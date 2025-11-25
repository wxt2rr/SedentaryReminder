import SwiftUI
import AppKit
import Combine

// MARK: - 窗口管理器
// 负责监听 AppState 并显示/隐藏特殊的 NSPanel 窗口
@MainActor
class OverlayWindowManager: ObservableObject {
    var appState: AppState
    private var popupPanel: NSPanel?
    private var fullScreenPanel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        setupBindings()
    }
    
    private func setupBindings() {
        // 监听中央弹窗触发
        appState.$showPopupAlert
            .sink { [weak self] show in
                if show { self?.showPopup() } else { self?.closePopup() }
            }
            .store(in: &cancellables)
        
        // 监听全屏触发
        appState.$showFullScreenAlert
            .sink { [weak self] show in
                if show { self?.showFullScreen() } else { self?.closeFullScreen() }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 中央弹窗逻辑
    private func showPopup() {
        guard popupPanel == nil else { return }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
        panel.hasShadow = false
        panel.center()
        // 中央弹窗允许点击穿透
        panel.ignoresMouseEvents = true
        
        panel.contentView = NSHostingView(rootView: PopupAlertView())
        panel.orderFrontRegardless()
        self.popupPanel = panel
    }
    
    private func closePopup() {
        popupPanel?.close()
        popupPanel = nil
    }
    
    // MARK: - 全屏覆盖逻辑
    private func showFullScreen() {
        guard fullScreenPanel == nil, let screen = NSScreen.main else { return }
        
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // .screenSaver 级别非常高，盖住菜单栏和 Dock
        panel.level = .screenSaver
        
        // 全屏模式必须拦截鼠标点击，否则无法点击跳过按钮
        panel.ignoresMouseEvents = false
        
        panel.contentView = NSHostingView(rootView: FullScreenOverlayView(appState: self.appState))
        // 确保窗口显示在最前并在当前空间
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.orderFrontRegardless()
        self.fullScreenPanel = panel
    }
    
    private func closeFullScreen() {
        fullScreenPanel?.close()
        fullScreenPanel = nil
    }
}

// MARK: - SwiftUI 视图定义

// 方案一：中央大图标弹窗视图
struct PopupAlertView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .cornerRadius(20)
            
            VStack(spacing: 20) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("起来活动一下!")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
            }
            .padding()
        }
        .frame(width: 280, height: 280)
        .onAppear { isAnimating = true }
    }
}

// 方案二：全屏毛玻璃覆盖视图 (优化了跳过按钮样式)
struct FullScreenOverlayView: View {
    let appState: AppState
    
    var body: some View {
        ZStack {
            // 底层毛玻璃
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            // 内容
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "figure.run")
                    .font(.system(size: 150))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("休息时间到")
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundColor(.white)
                
                Text("请站起来走动走动，眺望远方。")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                // 优化后的跳过按钮：更微妙，不那么突兀
                Button(action: {
                    appState.showFullScreenAlert = false
                }) {
                    Text("跳过本次提醒")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 60)
            }
        }
    }
}

// 用于实现 macOS 原生毛玻璃效果的包装器
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
