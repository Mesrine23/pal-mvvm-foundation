import SwiftUI
import PalDesignSystem

/// A lightly branded theme built from the system baseline — demonstrates that
/// theming is opt-in and that an app overrides only the tokens it cares about.
extension Theme {

    static var showcase: Theme {
        var theme = Theme.system
        theme.colors.accent = Color(red: 0.40, green: 0.28, blue: 0.82)
        return theme
    }
}
