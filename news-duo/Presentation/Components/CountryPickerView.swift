import SwiftUI

/// A grid of flags only; each flag is labelled with the country name for VoiceOver.
struct CountryPickerView: View {
    let selection: Country
    let onSelect: (Country) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(countries) { country in
                        flagButton(for: country)
                    }
                }
                .padding()
            }
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Icon + title: a title-only item isn't shown in a vertical bar.
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var countries: [Country] {
        Country.supported.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func flagButton(for country: Country) -> some View {
        let isSelected = country == selection
        return Button {
            onSelect(country)
            dismiss()
        } label: {
            Text(country.flag)
                .font(.system(size: 40))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(.tint, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(country.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
