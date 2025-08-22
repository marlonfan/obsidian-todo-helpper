import Foundation

// 应用配置管理
class AppConfig: ObservableObject {
    @Published var vaultPath: String = ""
    @Published var templatePath: String = ""
    @Published var todoSectionHeader: String = "### 重点事项"
    
    private let fileManager = FileManager.default
    
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
    }
    
    func saveConfig() {
        saveString(vaultPath, to: "vault_path.txt")
        saveString(templatePath, to: "template_path.txt")
        saveString(todoSectionHeader, to: "todo_header.txt")
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
    
    // 初始化
    func initialize() async {
        await getVaultPath()
        await loadTodayTodos()
        setupFileMonitoring()
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
        let todayContent = parser.createTodayFromTemplate(templateContent)
        
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
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: vaultPath)
            
            for file in files {
                if file.hasSuffix(".md") && isDailyNoteFile(file) {
                    let dateString = String(file.dropLast(3)) // 移除.md扩展名
                    
                    // 检查日期是否在近30天内
                    if let fileDate = dateFormatter.date(from: dateString),
                       fileDate >= thirtyDaysAgo {
                        let filePath = "\(vaultPath)/\(file)"
                        let content = try String(contentsOfFile: filePath, encoding: .utf8)
                        let todos = parser.parseTodos(from: content, sectionHeader: config.todoSectionHeader)
                        
                        if !todos.isEmpty {
                            dailyTodos.append(DailyTodos(date: dateString, todos: todos))
                        }
                    }
                }
            }
            
            // 按日期排序（最新的在前）
            dailyTodos.sort { $0.date > $1.date }
            allTodos = dailyTodos
            
        } catch {
            print("加载所有待办失败: \(error)")
            allTodos = []
        }
    }
    
    // 检查是否为日记文件
    private func isDailyNoteFile(_ fileName: String) -> Bool {
        let nameWithoutExt = String(fileName.dropLast(3))
        return nameWithoutExt.count == 10 && 
               nameWithoutExt.filter({ $0 == "-" }).count == 2 &&
               nameWithoutExt.allSatisfy({ $0.isNumber || $0 == "-" })
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
    
    // 切换历史待办状态
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
    
    deinit {
        fileMonitor?.cancel()
    }
}