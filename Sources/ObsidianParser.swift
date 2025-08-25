import Foundation

class ObsidianParser {
    static let shared = ObsidianParser()
    
    private init() {}
    
    // 解析待办事项
    func parseTodos(from content: String, sectionHeader: String = "### 重点事项") -> [Todo] {
        let lines = content.components(separatedBy: .newlines)
        var todos: [Todo] = []
        var inImportantSection = false
        var todoIndex = 0
        
        for line in lines {
            // 检查是否进入指定待办部分
            if line.hasPrefix(sectionHeader) {
                inImportantSection = true
                continue
            }
            
            // 检查是否进入其他章节
            if line.hasPrefix("### ") && !line.hasPrefix(sectionHeader) {
                inImportantSection = false
                continue
            }
            
            // 只处理指定部分的待办
            if inImportantSection {
                if let todo = parseTodoLine(line, index: todoIndex) {
                    todos.append(todo)
                    todoIndex += 1
                }
            }
        }
        
        return todos
    }
    
    // 解析单行待办事项
    private func parseTodoLine(_ line: String, index: Int) -> Todo? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 匹配 "- [x] content" 或 "- [ ] content" 格式
        let pattern = #"^- \[([ x])\] (.+)$"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(trimmedLine.startIndex..<trimmedLine.endIndex, in: trimmedLine)
            
            if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                let statusRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                
                guard let statusNSRange = Range(statusRange, in: trimmedLine),
                      let contentNSRange = Range(contentRange, in: trimmedLine) else {
                    return nil
                }
                
                let status = String(trimmedLine[statusNSRange])
                let content = String(trimmedLine[contentNSRange])
                let completed = status == "x"
                
                return Todo(id: index, content: content, completed: completed)
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        
        return nil
    }
    
    // 重构内容，更新待办状态
    func reconstructContent(_ originalContent: String, with updatedTodos: [Todo], sectionHeader: String = "### 重点事项") -> String {
        let lines = originalContent.components(separatedBy: .newlines)
        var resultLines: [String] = []
        var inImportantSection = false
        var todoIndex = 0
        
        for line in lines {
            if line.hasPrefix(sectionHeader) {
                inImportantSection = true
                resultLines.append(line)
                continue
            }
            
            if line.hasPrefix("### ") && !line.hasPrefix(sectionHeader) {
                inImportantSection = false
                resultLines.append(line)
                continue
            }
            
            if inImportantSection && isTodoLine(line) {
                if todoIndex < updatedTodos.count {
                    let todo = updatedTodos[todoIndex]
                    let status = todo.completed ? "x" : " "
                    let newLine = "- [\(status)] \(todo.content)"
                    resultLines.append(newLine)
                    todoIndex += 1
                }
                // 如果updatedTodos数量少于原始todo，则跳过这一行（即删除这个todo）
            } else {
                resultLines.append(line)
            }
        }
        
        return resultLines.joined(separator: "\n")
    }
    
    // 检查是否为待办行
    private func isTodoLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.range(of: #"^- \[([ x])\] .+"#, options: .regularExpression) != nil
    }
    
    // 添加新待办到内容中
    func addTodoToContent(_ content: String, newTodo: String, sectionHeader: String = "### 重点事项") -> String {
        let lines = content.components(separatedBy: .newlines)
        var resultLines: [String] = []
        var foundImportantSection = false
        var inImportantSection = false
        
        for line in lines {
            if line.hasPrefix(sectionHeader) {
                foundImportantSection = true
                inImportantSection = true
                resultLines.append(line)
                continue
            }
            
            if line.hasPrefix("### ") && !line.hasPrefix(sectionHeader) {
                if inImportantSection {
                    // 在指定部分结束之前添加新待办
                    resultLines.append("- [ ] \(newTodo)")
                    inImportantSection = false
                }
                resultLines.append(line)
                continue
            }
            
            resultLines.append(line)
        }
        
        // 如果仍在指定部分（文件结束），添加新待办
        if inImportantSection {
            resultLines.append("- [ ] \(newTodo)")
        }
        
        // 如果没有找到指定部分，创建一个
        if !foundImportantSection {
            if !content.isEmpty {
                resultLines.append("")
            }
            resultLines.append(sectionHeader)
            resultLines.append("- [ ] \(newTodo)")
        }
        
        return resultLines.joined(separator: "\n")
    }
    
    // 从模板创建今日文件内容
    func createTodayFromTemplate(_ templateContent: String, todoSectionHeader: String = "### 重点事项") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        // 替换模板中的日期占位符
        var content = templateContent.replacingOccurrences(of: "{{date}}", with: today)
        content = content.replacingOccurrences(of: "{{today}}", with: today)
        
        // 如果模板为空，创建基本结构
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content = "\(today)\n\n\(todoSectionHeader)\n\n"
        }
        
        return content
    }
}