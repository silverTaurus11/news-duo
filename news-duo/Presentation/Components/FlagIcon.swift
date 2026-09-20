import SwiftUI

/// An emoji flag rendered as an `Image`.
///
/// Toolbar items need a real icon. On iPhone Duo's outer display bars present
/// vertically and show icons only; an item with no icon is not shown there.
/// SwiftUI treats only an `Image` as a `Label` icon (a `Text` icon is dropped),
/// so the emoji is rendered once per country and cached.
enum FlagIcon {
    private static var cache: [String: UIImage] = [:]

    static func image(for country: Country) -> Image {
        if let cached = cache[country.code] {
            return Image(uiImage: cached).renderingMode(.original).resizable()
        }
        let renderer = ImageRenderer(content: Text(country.flag).font(.system(size: 22)))
        renderer.scale = 3
        guard let rendered = renderer.uiImage else { return Image(systemName: "flag") }
        let original = rendered.withRenderingMode(.alwaysOriginal)
        cache[country.code] = original
        return Image(uiImage: original).renderingMode(.original).resizable()
    }
}
