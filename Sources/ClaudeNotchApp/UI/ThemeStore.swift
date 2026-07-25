import Foundation

/// Holds the theme list + the current selection, persisted to UserDefaults.
final class ThemeStore {
    private let key = "notch.themeID"
    let all: [Theme] = Themes.all
    private(set) var current: Theme

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: key)
        self.current = Themes.all.first { $0.id == saved } ?? Themes.default
    }
    private let defaults: UserDefaults

    /// Select by id; persists. Unknown id is ignored. Returns the new current theme.
    @discardableResult
    func select(id: String) -> Theme {
        guard let t = all.first(where: { $0.id == id }) else { return current }
        current = t
        defaults.set(id, forKey: key)
        return t
    }
}
