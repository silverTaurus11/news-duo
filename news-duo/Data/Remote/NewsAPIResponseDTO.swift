import Foundation

nonisolated struct NewsAPIResponseDTO: Decodable {
    let status: String
    let totalResults: Int?
    let articles: [ArticleDTO]?
    /// Present when `status == "error"`.
    let code: String?
    let message: String?
}

nonisolated struct ArticleDTO: Decodable {
    let source: SourceDTO?
    let author: String?
    let title: String?
    let description: String?
    let url: String?
    let urlToImage: String?
    let publishedAt: String?
    let content: String?
}

nonisolated struct SourceDTO: Decodable {
    let name: String?
}
