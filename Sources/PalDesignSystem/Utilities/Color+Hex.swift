import SwiftUI

public extension Color {

    /// A color from a 24-bit RGB value — the compile-checked form for
    /// design-token layers: `Color(hex: 0xF3F1EC)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A color from a design-tool hex string — `"#F3F1EC"`, `"F3F1EC"`, or
    /// 8-digit RGBA `"#F3F1ECCC"`. Fails on any other shape.
    init?(hex string: String) {
        let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt32(cleaned, radix: 16) else { return nil }
        if cleaned.count == 6 {
            self.init(hex: value)
        } else {
            self.init(hex: value >> 8, opacity: Double(value & 0xFF) / 255)
        }
    }
}
