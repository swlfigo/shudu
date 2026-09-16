nonisolated enum Difficulty: String, CaseIterable, Sendable {
    case easy, medium, hard

    var hintCount: Int {
        switch self {
        case .easy: 3
        case .medium: 2
        case .hard: 1
        }
    }

    var displayName: String {
        switch self {
        case .easy: "简单"
        case .medium: "中等"
        case .hard: "困难"
        }
    }

    var givenFloor: Int {
        switch self {
        case .easy: 36
        case .medium: 28
        case .hard: 22
        }
    }
}
