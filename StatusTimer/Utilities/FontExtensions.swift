import SwiftUI

extension Font {
    /// Helvetica Neue Thin — the Braun/Dieter Rams typeface for numerals
    static func helveticaNeue(size: CGFloat) -> Font {
        Font(NSFont(name: "HelveticaNeue-Thin", size: size) ?? .systemFont(ofSize: size, weight: .thin))
    }
}
