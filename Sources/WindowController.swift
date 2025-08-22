import AppKit

class WindowController: ObservableObject {
    private let window: NSWindow
    
    init(window: NSWindow) {
        self.window = window
    }
    
    func resizeWindow(width: CGFloat, height: CGFloat, animated: Bool = true) {
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x - (width - currentFrame.width), // 向左展开
            y: currentFrame.origin.y + (currentFrame.height - height), // 保持窗口顶部位置不变
            width: width,
            height: height
        )
        
        window.setFrame(newFrame, display: true, animate: animated)
    }
    
    func startDragging() {
        // 在macOS中，设置isMovableByWindowBackground = true已经足够
        // 这个方法保留以便将来扩展
    }
}