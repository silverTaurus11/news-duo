import SwiftUI

/// A horizontally scrolling row of single-select chips.
struct FilterChipBar<Value: Hashable>: View {
    struct Chip: Identifiable {
        let value: Value
        let title: String

        var id: Value { value }
    }

    let chips: [Chip]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    let isSelected = chip.value == selection
                    Button {
                        onSelect(chip.value)
                    } label: {
                        Text(chip.title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                            .background(
                                isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
