nonisolated enum NewsCategory: String, CaseIterable, Identifiable, Sendable {
    case business
    case entertainment
    case general
    case health
    case science
    case sports
    case technology

    var id: String { rawValue }
}
