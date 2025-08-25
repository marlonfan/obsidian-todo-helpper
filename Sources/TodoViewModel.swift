import Foundation
import SwiftUI

// 应用配置管理
class AppConfig: ObservableObject {
    @Published var vaultPath: String = ""
    @Published var templatePath: String = ""
    @Published var todoSectionHeader: String = "### 重点事项"
    @Published var clockColor: String = "black"
    
    private let fileManager = FileManager.default
    
    // 预设的护眼颜色选项
    static let eyeFriendlyColors: [(name: String, value: String, color: Color)] = [
        ("经典黑色", "black", .black),
        ("深灰色", "darkGray", Color(NSColor.darkGray)),
        ("海军蓝", "navyBlue", Color(red: 0.0, green: 0.2, blue: 0.4)),
        ("深绿色", "darkGreen", Color(red: 0.0, green: 0.4, blue: 0.2)),
        ("深棕色", "darkBrown", Color(red: 0.4, green: 0.2, blue: 0.1)),
        ("紫罗兰", "violet", Color(red: 0.3, green: 0.1, blue: 0.5)),
        ("深青色", "teal", Color(red: 0.0, green: 0.5, blue: 0.5)),
        ("深红色", "deepRed", Color(red: 0.5, green: 0.0, blue: 0.1)),
        ("深粉色", "deepPink", Color(red: 0.5, green: 0.2, blue: 0.4)),
        ("橙棕色", "orangeBrown", Color(red: 0.6, green: 0.3, blue: 0.1)),
        ("深橄榄", "deepOlive", Color(red: 0.3, green: 0.4, blue: 0.2)),
        ("深紫色", "deepPurple", Color(red: 0.2, green: 0.1, blue: 0.4))
    ]
    
    private var configDirectory: String {
        guard let homeDirectory = fileManager.homeDirectoryForCurrentUser.path as String? else {
            return ""
        }
        return "\(homeDirectory)/Library/Application Support/ObsidianTodoMac"
    }
    
    init() {
        loadConfig()
    }
    
    func loadConfig() {
        vaultPath = getSavedString(for: "vault_path.txt") ?? ""
        templatePath = getSavedString(for: "template_path.txt") ?? ""
        todoSectionHeader = getSavedString(for: "todo_header.txt") ?? "### 重点事项"
        clockColor = getSavedString(for: "clock_color.txt") ?? "black"
    }
    
    func saveConfig() {
        saveString(vaultPath, to: "vault_path.txt")
        saveString(templatePath, to: "template_path.txt")
        saveString(todoSectionHeader, to: "todo_header.txt")
        saveString(clockColor, to: "clock_color.txt")
    }
    
    private func getSavedString(for fileName: String) -> String? {
        let configFile = "\(configDirectory)/\(fileName)"
        return try? String(contentsOfFile: configFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func saveString(_ value: String, to fileName: String) {
        let configFile = "\(configDirectory)/\(fileName)"
        
        do {
            try fileManager.createDirectory(atPath: configDirectory, withIntermediateDirectories: true)
            try value.write(toFile: configFile, atomically: true, encoding: .utf8)
        } catch {
            print("保存配置失败 \(fileName): \(error)")
        }
    }
}

@MainActor
class TodoViewModel: ObservableObject {
    @Published var todayTodos: [Todo] = []
    @Published var allTodos: [DailyTodos] = []
    @Published var config = AppConfig()
    
    var vaultPath: String {
        return config.vaultPath
    }
    
    private let fileManager = FileManager.default
    private let parser = ObsidianParser.shared
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var lastUpdateDate: Date?
    private var dateCheckTimer: Timer?
    
    deinit {
        dateCheckTimer?.invalidate()
        fileMonitor?.cancel()
    }
    
    // 初始化
    func initialize() async {
        await getVaultPath()
        await loadTodayTodos()
        setupFileMonitoring()
        setupDateCheckTimer()
        lastUpdateDate = Date()
    }
    
    // 获取仓库路径
    func getVaultPath() async {
        // 如果配置中有路径，直接使用
        if !config.vaultPath.isEmpty {
            return
        }
        
        // 自动搜索常见位置
        if let detectedPath = findObsidianVault() {
            config.vaultPath = detectedPath
            config.saveConfig()
        }
    }
    
    // 查找Obsidian仓库
    private func findObsidianVault() -> String? {
        guard let homeDirectory = fileManager.homeDirectoryForCurrentUser.path as String? else {
            return nil
        }
        
        let possiblePaths = [
            "\(homeDirectory)/Documents/Obsidian",
            "\(homeDirectory)/Obsidian",
            "\(homeDirectory)/Documents"
        ]
        
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    // 设置目录
    func setDirectory(_ path: String) async {
        guard fileManager.fileExists(atPath: path) else {
            print("目录不存在: \(path)")
            return
        }
        
        config.vaultPath = path
        config.saveConfig()
        await loadTodayTodos()
        setupFileMonitoring()
    }
    
    // 获取今日文件路径
    private func getTodayFilePath() -> String? {
        guard !vaultPath.isEmpty && vaultPath != "未找到 Obsidian 仓库" else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        return "\(vaultPath)/\(today).md"
    }
    
    // 加载今日待办
    func loadTodayTodos() async {
        guard let filePath = getTodayFilePath() else {
            todayTodos = []
            return
        }
        
        // 如果今日文件不存在，尝试从模板创建
        if !fileManager.fileExists(atPath: filePath) {
            await createTodayFileFromTemplate()
        }
        
        guard fileManager.fileExists(atPath: filePath) else {
            todayTodos = []
            return
        }
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            todayTodos = parser.parseTodos(from: content, sectionHeader: config.todoSectionHeader)
        } catch {
            print("加载今日待办失败: \(error)")
            todayTodos = []
        }
    }
    
    // 从模板创建今日文件
    private func createTodayFileFromTemplate() async {
        guard let filePath = getTodayFilePath() else { return }
        
        var templateContent = ""
        
        // 尝试读取模板文件
        if !config.templatePath.isEmpty && fileManager.fileExists(atPath: config.templatePath) {
            do {
                templateContent = try String(contentsOfFile: config.templatePath, encoding: .utf8)
            } catch {
                print("读取模板文件失败: \(error)")
            }
        }
        
        // 创建今日文件内容
        let todayContent = parser.createTodayFromTemplate(templateContent, todoSectionHeader: config.todoSectionHeader)
        
        do {
            // 确保目录存在
            let directoryPath = (filePath as NSString).deletingLastPathComponent
            try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
            
            // 写入文件
            try todayContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("已从模板创建今日文件: \(filePath)")
        } catch {
            print("创建今日文件失败: \(error)")
        }
    }
    
    // 加载所有待办
    func loadAllTodos() async {
        guard !vaultPath.isEmpty && vaultPath != "未找到 Obsidian 仓库" else {
            allTodos = []
            return
        }
        
        var dailyTodos: [DailyTodos] = []
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 生成过去30天的日期列表，而不是扫描目录
        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else {
                continue
            }
            
            let dateString = dateFormatter.string(from: date)
            let filePath = "\(vaultPath)/\(dateString).md"
            
            // 检查文件是否存在
            guard fileManager.fileExists(atPath: filePath) else {
                continue
            }
            
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let todos = parser.parseTodos(from: content, sectionHeader: config.todoSectionHeader)
                
                if !todos.isEmpty {
                    dailyTodos.append(DailyTodos(date: dateString, todos: todos))
                }
            } catch {
                print("加载文件失败 \(filePath): \(error)")
                continue
            }
        }
        
        // dailyTodos已经按日期排序（最新的在前）
        allTodos = dailyTodos
    }
    
    // 切换待办状态
    func toggleTodo(index: Int, completed: Bool) async {
        guard let filePath = getTodayFilePath(),
              fileManager.fileExists(atPath: filePath),
              index < todayTodos.count else {
            return
        }
        
        // 更新本地数据
        todayTodos[index] = Todo(
            id: todayTodos[index].id,
            content: todayTodos[index].content,
            completed: completed
        )
        
        // 更新文件
        do {
            let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let updatedContent = parser.reconstructContent(originalContent, with: todayTodos, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("更新待办状态失败: \(error)")
            // 恢复原状态
            await loadTodayTodos()
        }
    }
    
    // 添加新待办
    func addTodo(content: String) async {
        guard let filePath = getTodayFilePath() else {
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return
        }
        
        do {
            var fileContent: String
            
            if fileManager.fileExists(atPath: filePath) {
                fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
            } else {
                // 创建新文件
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let today = formatter.string(from: Date())
                fileContent = today
                
                // 确保目录存在
                let directoryPath = (filePath as NSString).deletingLastPathComponent
                try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
            }
            
            let updatedContent = parser.addTodoToContent(fileContent, newTodo: trimmedContent, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // 重新加载待办
            await loadTodayTodos()
            
        } catch {
            print("添加待办失败: \(error)")
        }
    }
    
    // 设置文件监控
    private func setupFileMonitoring() {
        // 清理现有监控
        fileMonitor?.cancel()
        fileMonitor = nil
        
        guard let filePath = getTodayFilePath(),
              fileManager.fileExists(atPath: filePath) else {
            return
        }
        
        let fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }
        
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .background)
        )
        
        fileMonitor?.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.loadTodayTodos()
            }
        }
        
        fileMonitor?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileMonitor?.resume()
    }
    
    // 设置日期检查定时器
    private func setupDateCheckTimer() {
        dateCheckTimer?.invalidate()
        dateCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                await self?.checkDateChange()
            }
        }
    }
    
    // 检查日期是否变化
    private func checkDateChange() async {
        let calendar = Calendar.current
        let now = Date()
        
        guard let lastDate = lastUpdateDate else {
            lastUpdateDate = now
            return
        }
        
        // 检查日期是否不同
        if !calendar.isDate(now, inSameDayAs: lastDate) {
            print("检测到日期变化，重新加载数据")
            lastUpdateDate = now
            await loadTodayTodos()
            // 如果all todos已经加载过，也重新加载
            if !allTodos.isEmpty {
                await loadAllTodos()
            }
        }
    }
    
    // 编辑待办内容
    func editTodo(index: Int, newContent: String) async {
        guard let filePath = getTodayFilePath(),
              fileManager.fileExists(atPath: filePath),
              index < todayTodos.count else {
            return
        }
        
        let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return
        }
        
        // 更新本地数据
        todayTodos[index] = Todo(
            id: todayTodos[index].id,
            content: trimmedContent,
            completed: todayTodos[index].completed
        )
        
        // 更新文件
        do {
            let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let updatedContent = parser.reconstructContent(originalContent, with: todayTodos, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("编辑待办失败: \(error)")
            // 恢复原状态
            await loadTodayTodos()
        }
    }
    
    // 删除待办
    func deleteTodo(index: Int) async {
        guard let filePath = getTodayFilePath(),
              fileManager.fileExists(atPath: filePath),
              index < todayTodos.count else {
            return
        }
        
        // 更新本地数据
        todayTodos.remove(at: index)
        
        // 重新编号todos
        for i in 0..<todayTodos.count {
            todayTodos[i] = Todo(
                id: i,
                content: todayTodos[i].content,
                completed: todayTodos[i].completed
            )
        }
        
        // 更新文件
        do {
            let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let updatedContent = parser.reconstructContent(originalContent, with: todayTodos, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("删除待办失败: \(error)")
            // 恢复原状态
            await loadTodayTodos()
        }
    }
    
    // 编辑历史待办
    func editHistoricalTodo(date: String, todoIndex: Int, newContent: String) async {
        let filePath = "\(vaultPath)/\(date).md"
        
        guard fileManager.fileExists(atPath: filePath) else {
            return
        }
        
        let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return
        }
        
        do {
            let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let todos = parser.parseTodos(from: originalContent, sectionHeader: config.todoSectionHeader)
            
            guard todoIndex < todos.count else {
                return
            }
            
            // 更新todo列表
            var updatedTodos = todos
            updatedTodos[todoIndex] = Todo(
                id: todos[todoIndex].id,
                content: trimmedContent,
                completed: todos[todoIndex].completed
            )
            
            // 重构文件内容
            let updatedContent = parser.reconstructContent(originalContent, with: updatedTodos, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // 重新加载全部待办以反映更改
            await loadAllTodos()
            
        } catch {
            print("编辑历史待办失败: \(error)")
        }
    }
    
    // 删除历史待办
    func deleteHistoricalTodo(date: String, todoIndex: Int) async {
        let filePath = "\(vaultPath)/\(date).md"
        
        guard fileManager.fileExists(atPath: filePath) else {
            return
        }
        
        do {
            let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
            var todos = parser.parseTodos(from: originalContent, sectionHeader: config.todoSectionHeader)
            
            guard todoIndex < todos.count else {
                return
            }
            
            // 删除指定todo
            todos.remove(at: todoIndex)
            
            // 重新编号todos
            for i in 0..<todos.count {
                todos[i] = Todo(
                    id: i,
                    content: todos[i].content,
                    completed: todos[i].completed
                )
            }
            
            // 重构文件内容
            let updatedContent = parser.reconstructContent(originalContent, with: todos, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // 重新加载全部待办以反映更改
            await loadAllTodos()
            
        } catch {
            print("删除历史待办失败: \(error)")
        }
    }
    func toggleHistoricalTodo(date: String, todoIndex: Int, completed: Bool) async {
        let filePath = "\(vaultPath)/\(date).md"
        
        guard fileManager.fileExists(atPath: filePath) else {
            return
        }
        
        do {
            let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let todos = parser.parseTodos(from: originalContent, sectionHeader: config.todoSectionHeader)
            
            guard todoIndex < todos.count else {
                return
            }
            
            // 更新todo列表
            var updatedTodos = todos
            updatedTodos[todoIndex] = Todo(
                id: todos[todoIndex].id,
                content: todos[todoIndex].content,
                completed: completed
            )
            
            // 重构文件内容
            let updatedContent = parser.reconstructContent(originalContent, with: updatedTodos, sectionHeader: config.todoSectionHeader)
            try updatedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // 重新加载全部待办以反映更改
            await loadAllTodos()
            
        } catch {
            print("更新历史待办状态失败: \(error)")
        }
    }
}