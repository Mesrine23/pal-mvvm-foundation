import Foundation
import PalNetworking

/// Endpoint factories for the posts API — defined in the Data layer per the convention.
extension Request {

    /// `GET /posts?_page=N&_limit=M` → one page of posts.
    static func posts(page: Int, limit: Int) -> Request<[PostDTO]> {
        Request<[PostDTO]>(
            path: "/posts",
            query: [
                URLQueryItem(name: "_page", value: String(page)),
                URLQueryItem(name: "_limit", value: String(limit)),
            ]
        )
    }
}
