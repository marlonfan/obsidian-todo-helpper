import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    @ObservedObject var windowController: WindowController
    @State private var isExpanded = false
    @State private var hoverTimer: Timer?
    
    var body: some View {
        Group {
            if isExpanded {
                ExpandedView(viewModel: viewModel)
                    .frame(width: 480, height: 560)
                    .onHover { hovering in
                        handleHover(hovering: hovering)
                    }
            } else {
                CompactView { hovering in
                    handleHover(hovering: hovering)
                }
                .frame(width: 180, height: 120)
            }
        }
        .background(Color.clear)
    }
    
    private func handleHover(hovering: Bool) {
        // 取消之前的定时器
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        if hovering {
            // 鼠标进入，立即展开
            if !isExpanded {
                expandWindow()
            }
        } else {
            // 鼠标离开，延迟收起以避免快速移动时的闪烁
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                if isExpanded {
                    compactWindow()
                }
            }
        }
    }
    
    private func expandWindow() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = true
        }
        windowController.resizeWindow(width: 480, height: 560)
    }
    
    private func compactWindow() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = false
        }
        windowController.resizeWindow(width: 180, height: 120)
    }
}

struct CompactView: View {
    @State private var currentTime = Date()
    @State private var isTimeTextHovered = false
    let onHover: (Bool) -> Void
    
    var body: some View {
        VStack {
            Text(formatTime(currentTime))
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)
                .scaleEffect(isTimeTextHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isTimeTextHovered)
                .onHover { hovering in
                    isTimeTextHovered = hovering
                    onHover(hovering) // 只有时间文字区域的hover才会触发
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            // 每秒更新时间
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct ExpandedView: View {
    @ObservedObject var viewModel: TodoViewModel
    @State private var showingAllTodos = false
    @State private var newTodoText = ""
    @State private var showingDirectoryInput = false
    @State private var directoryPath = ""
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: showingAllTodos ? "list.bullet" : "calendar")
                        .foregroundColor(.blue)
                        .font(.headline)
                    Text(showingAllTodos ? "所有待办 (近30天)" : "今日待办")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button("今日") {
                        showingAllTodos = false
                        Task { await viewModel.loadTodayTodos() }
                    }
                    .buttonStyle(ModernToggleButtonStyle(isActive: !showingAllTodos))
                    
                    Button("全部") {
                        showingAllTodos = true
                        Task { await viewModel.loadAllTodos() }
                    }
                    .buttonStyle(ModernToggleButtonStyle(isActive: showingAllTodos))
                    
                    Button {
                        showingSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("设置")
                }
            }
            
            // 仓库路径信息
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(viewModel.config.vaultPath.isEmpty ? "未找到 Obsidian 仓库" : URL(fileURLWithPath: viewModel.config.vaultPath).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        selectDirectory()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("选择目录")
                    
                    Button {
                        showingDirectoryInput.toggle()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("手动输入路径")
                }
            }
            
            if showingDirectoryInput {
                VStack(spacing: 12) {
                    // 路径输入框
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        TextField("输入目录路径...", text: $directoryPath)
                            .textFieldStyle(.plain)
                            .font(.body)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // 按钮组
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await viewModel.setDirectory(directoryPath)
                                showingDirectoryInput = false
                                directoryPath = ""
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("设置")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showingDirectoryInput = false
                            directoryPath = ""
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("取消")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 设置界面
            if showingSettings {
                SettingsView(viewModel: viewModel, isShowing: $showingSettings)
                    .transition(.opacity)
            }
            
            Divider()
            
            // 待办列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if showingAllTodos {
                        ForEach(viewModel.allTodos, id: \.date) { dailyTodos in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dailyTodos.date)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                
                                ForEach(Array(dailyTodos.todos.enumerated()), id: \.offset) { index, todo in
                                    TodoRowView(
                                        todo: todo,
                                        isReadOnly: false, // 允许编辑历史todo
                                        onToggle: { _, completed in
                                            Task {
                                                await viewModel.toggleHistoricalTodo(date: dailyTodos.date, todoIndex: index, completed: completed)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    } else {
                        ForEach(viewModel.todayTodos, id: \.id) { todo in
                            TodoRowView(
                                todo: todo,
                                isReadOnly: false,
                                onToggle: { index, completed in
                                    Task {
                                        await viewModel.toggleTodo(index: index, completed: completed)
                                    }
                                }
                            )
                        }
                    }
                    
                    if (showingAllTodos ? viewModel.allTodos.isEmpty : viewModel.todayTodos.isEmpty) {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.largeTitle)
                                .foregroundColor(.green)
                            Text("暂无待办事项")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if !showingAllTodos {
                                Text("添加新的待办开始规划你的一天吧！")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            
            // 添加待办输入框（仅在今日模式下显示）
            if !showingAllTodos {
                VStack(spacing: 8) {
                    // 输入框区域
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        TextField("添加新待办，按回车确认...", text: $newTodoText)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focusable(true)
                            .onSubmit {
                                addNewTodo()
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // 快捷提示
                    if newTodoText.isEmpty {
                        HStack {
                            Text("💡 直接输入内容，按回车即可添加")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        )
        .task {
            await viewModel.initialize()
        }
    }
    
    private func addNewTodo() {
        let trimmedText = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        Task {
            await viewModel.addTodo(content: trimmedText)
            newTodoText = ""
        }
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "选择 Obsidian 仓库目录"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    await viewModel.setDirectory(url.path)
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MM月dd日"
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "今天"
            } else if calendar.isDateInYesterday(date) {
                return "昨天"
            } else {
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
    }
}

struct TodoRowView: View {
    let todo: Todo
    let isReadOnly: Bool
    let onToggle: (Int, Bool) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: {
                if !isReadOnly {
                    onToggle(todo.id, !todo.completed)
                }
            }) {
                Image(systemName: todo.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.completed ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isReadOnly)
            
            Text(todo.content)
                .font(.body)
                .strikethrough(todo.completed)
                .foregroundColor(todo.completed ? .secondary : .primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(todo.completed ? Color.green.opacity(0.1) : Color.clear)
        )
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: TodoViewModel
    @Binding var isShowing: Bool
    @State private var tempTodoHeader: String = ""
    @State private var tempTemplatePath: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("⚙️ 设置")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    isShowing = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 12) {
                // 待办事项标识设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.badge.checkmark")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text("待办识别标题")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    TextField("例如: ### 重点事项", text: $tempTodoHeader)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // 模板文件设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text("模板文件路径")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        TextField("选择模板文件路径（可选）", text: $tempTemplatePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                        
                        Button {
                            selectTemplateFile()
                        } label: {
                            Image(systemName: "folder")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                        .help("选择模板文件")
                    }
                }
                
                // 模板说明
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 模板说明")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("• 当日志文件不存在时，会自动使用模板创建\n• 支持 {{date}} 和 {{today}} 占位符\n• 留空则创建基本格式的日志文件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 保存按钮
            HStack {
                Button("重置") {
                    tempTodoHeader = "### 重点事项"
                    tempTemplatePath = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("保存") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            tempTodoHeader = viewModel.config.todoSectionHeader
            tempTemplatePath = viewModel.config.templatePath
        }
    }
    
    private func selectTemplateFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .plainText]
        panel.message = "选择模板文件"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                tempTemplatePath = url.path
            }
        }
    }
    
    private func saveSettings() {
        viewModel.config.todoSectionHeader = tempTodoHeader.isEmpty ? "### 重点事项" : tempTodoHeader
        viewModel.config.templatePath = tempTemplatePath
        viewModel.config.saveConfig()
        
        // 重新加载数据以应用新设置
        Task {
            await viewModel.loadTodayTodos()
            await viewModel.loadAllTodos()
        }
        
        isShowing = false
    }
}

struct ModernToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.blue : Color.gray.opacity(0.2))
            )
            .foregroundColor(isActive ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}