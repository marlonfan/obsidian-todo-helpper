import SwiftUI
import AppKit

// 自定义窗口类以支持键盘输入
class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

@main
struct ObsidianTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 返回一个永不显示的窗口
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
        .windowResizability(.contentSize)
        .commands {
            // 移除所有默认菜单命令
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .printItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingWindow!
    var hostingView: NSHostingView<ContentView>!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏默认创建的窗口
        for window in NSApp.windows {
            window.close()
        }
        
        // 创建主窗口
        window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口属性
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        
        // 设置初始位置（右上角）
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let windowFrame = NSRect(
            x: screenFrame.maxX - 200,
            y: screenFrame.maxY - 140,
            width: 180,
            height: 120
        )
        window.setFrame(windowFrame, display: true)
        
        // 创建SwiftUI内容
        let contentView = ContentView(windowController: WindowController(window: window))
        hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        // 显示窗口并使其成为关键窗口
        window.makeKeyAndOrderFront(nil)
        
        // 隐藏Dock图标
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}