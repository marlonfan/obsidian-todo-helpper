import AppKit

class WindowController: ObservableObject {
    private let window: NSWindow
    private var anchorPoint: NSPoint?
    
    init(window: NSWindow) {
        self.window = window
        // 保存初始位置作为锚点（右上角）
        let frame = window.frame
        anchorPoint = NSPoint(x: frame.maxX, y: frame.maxY)
        
        // 监听窗口位置变化，当用户拖拽时更新锚点
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updateAnchorPoint()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func resizeWindow(width: CGFloat, height: CGFloat, animated: Bool = true) {
        guard let anchor = anchorPoint else { return }
        
        // 基于固定锚点计算新位置，确保右上角位置不变
        let newFrame = NSRect(
            x: anchor.x - width,  // 从右上角锚点向左计算
            y: anchor.y - height, // 从右上角锚点向下计算
            width: width,
            height: height
        )
        
        window.setFrame(newFrame, display: true, animate: animated)
    }
    
    // 更新锚点位置（当用户拖拽窗口时调用）
    func updateAnchorPoint() {
        let frame = window.frame
        anchorPoint = NSPoint(x: frame.maxX, y: frame.maxY)
    }
    
    func startDragging() {
        // 在macOS中，设置isMovableByWindowBackground = true已经足够
        // 这个方法保留以便将来扩展
    }
}