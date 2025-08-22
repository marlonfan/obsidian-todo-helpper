import Foundation

struct Todo: Identifiable, Codable {
    let id: Int
    let content: String
    let completed: Bool
}

struct DailyTodos: Identifiable {
    let id = UUID()
    let date: String
    let todos: [Todo]
}