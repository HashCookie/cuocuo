import Foundation

enum ChoiceOptions {
    static let standard = ["A", "B", "C", "D"]
    static let all = ["A", "B", "C", "D", "E"]

    static func normalized(_ letters: [String]) -> [String] {
        let unique = all.filter { letters.contains($0) }
        return unique.isEmpty ? standard : unique
    }
}
