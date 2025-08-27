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
    
    // 检查是否为不完整的待办行（如 "- " 或 "- []"）
    private func isIncompleteTodoLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == "-" || trimmedLine == "- " || trimmedLine == "- []" || trimmedLine == "- [ ]"
    }
    
    // 添加新待办到内容中
    func addTodoToContent(_ content: String, newTodo: String, sectionHeader: String = "### 重点事项") -> String {
        let lines = content.components(separatedBy: .newlines)
        var resultLines: [String] = []
        var foundImportantSection = false
        var inImportantSection = false
        var insertIndex = -1
        var replaceIncompleteIndex = -1
        
        for (_, line) in lines.enumerated() {
            if line.hasPrefix(sectionHeader) {
                foundImportantSection = true
                inImportantSection = true
                resultLines.append(line)
                continue
            }
            
            // 检查是否离开重点事项章节
            if line.hasPrefix("### ") && !line.hasPrefix(sectionHeader) {
                if inImportantSection {
                    // 找到插入位置：在该章节结束处
                    insertIndex = resultLines.count
                }
                inImportantSection = false
            }
            
            // 如果在重点事项章节中
            if inImportantSection {
                // 检查是否为不完整的待办行，如果是则标记替换位置
                if isIncompleteTodoLine(line) && replaceIncompleteIndex == -1 {
                    replaceIncompleteIndex = resultLines.count
                    resultLines.append("- [ ] \(newTodo)") // 直接替换不完整的行
                    continue
                }
                // 如果遇到完整的todo行，先添加这一行，然后更新插入位置
                else if isTodoLine(line) {
                    resultLines.append(line)
                    insertIndex = resultLines.count // 在当前todo之后
                    continue
                }
            }
            
            resultLines.append(line)
        }
        
        // 如果找到了不完整的待办行并已替换，直接返回结果
        if replaceIncompleteIndex >= 0 {
            return resultLines.joined(separator: "\n")
        }
        
        // 如果仍在重点事项章节（文件结束）
        if inImportantSection {
            insertIndex = resultLines.count
        }
        
        // 插入新todo
        if insertIndex >= 0 {
            resultLines.insert("- [ ] \(newTodo)", at: insertIndex)
        } else if foundImportantSection {
            // 如果找到了章节但没有合适的插入位置（空章节）
            // 在章节标题后直接插入
            for (index, line) in resultLines.enumerated() {
                if line.hasPrefix(sectionHeader) {
                    resultLines.insert("- [ ] \(newTodo)", at: index + 1)
                    break
                }
            }
        } else {
            // 如果没有找到重点事项章节，创建一个
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