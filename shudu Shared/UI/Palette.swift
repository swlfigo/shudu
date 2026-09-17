import Foundation
import SpriteKit

enum ThemePreference: String, CaseIterable {
    case system
    case light
    case dark

    private static let storageKey = "themePreference"

    var displayName: String {
        switch self {
        case .system: return "跟随"
        case .light: return "日间"
        case .dark: return "夜间"
        }
    }

    var next: ThemePreference {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }

    static var current: ThemePreference {
        get {
            ThemePreference(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    func resolved(systemIsDark: Bool) -> Palette.Appearance {
        switch self {
        case .system: return systemIsDark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum Palette {
    enum Appearance {
        case light
        case dark
    }

    static var appearance: Appearance = .dark

    static var background: SKColor { colors.background }
    static var paper: SKColor { colors.paper }
    static var ink: SKColor { colors.ink }
    static var userInk: SKColor { colors.userInk }
    static var selected: SKColor { colors.selected }
    static var peer: SKColor { colors.peer }
    static var sameDigit: SKColor { colors.sameDigit }
    static var conflictFill: SKColor { colors.conflictFill }
    static var conflictInk: SKColor { colors.conflictInk }
    static var note: SKColor { colors.note }
    static var key: SKColor { colors.key }
    static var hintKey: SKColor { colors.hintKey }
    static var noteOn: SKColor { colors.noteOn }
    static var line: SKColor { colors.line }
    static var hudText: SKColor { colors.hudText }
    static var keyText: SKColor { colors.keyText }

    private struct Colors {
        var background: SKColor
        var paper: SKColor
        var ink: SKColor
        var userInk: SKColor
        var selected: SKColor
        var peer: SKColor
        var sameDigit: SKColor
        var conflictFill: SKColor
        var conflictInk: SKColor
        var note: SKColor
        var key: SKColor
        var hintKey: SKColor
        var noteOn: SKColor
        var line: SKColor
        var hudText: SKColor
        var keyText: SKColor
    }

    private static func hex(_ rgb: UInt32) -> SKColor {
        SKColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    private static let darkColors = Colors(
        background: hex(0x1C1916),
        paper: hex(0xEFE4CC),
        ink: hex(0x2B2118),
        userInk: hex(0x3D5C8A),
        selected: hex(0xD7C49A),
        peer: hex(0xF4EAD4),
        sameDigit: hex(0xE4D4A8),
        conflictFill: hex(0xF0C8B4),
        conflictInk: hex(0x8A2A1A),
        note: hex(0x7A6A58),
        key: hex(0x2A2420),
        hintKey: hex(0x3A4A38),
        noteOn: hex(0xD4B483),
        line: hex(0x3A2F24),
        hudText: hex(0xEFE4CC),
        keyText: hex(0xEFE4CC)
    )

    private static let lightColors = Colors(
        background: hex(0xD9D0C3),
        paper: hex(0xFFF8EC),
        ink: hex(0x2B2118),
        userInk: hex(0x345C8C),
        selected: hex(0xE6D3A4),
        peer: hex(0xF3EADF),
        sameDigit: hex(0xE2D09C),
        conflictFill: hex(0xE8B8A8),
        conflictInk: hex(0x8A2A1A),
        note: hex(0x6E5E4E),
        key: hex(0xCFC6B8),
        hintKey: hex(0xB7C4B0),
        noteOn: hex(0xA67C3D),
        line: hex(0x3A2F24),
        hudText: hex(0x2B2118),
        keyText: hex(0x2B2118)
    )

    private static var colors: Colors {
        appearance == .light ? lightColors : darkColors
    }
}
