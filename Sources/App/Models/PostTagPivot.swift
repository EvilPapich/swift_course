import FluentMySQL
import Vapor

final class PostTagPivot: MySQLPivot {
    typealias Left = Post

    typealias Right = Tag

    var id: Int?

    var postId: Post.ID
    var tagId: Tag.ID

    static var leftIDKey: LeftIDKey = \PostTagPivot.postId

    static var rightIDKey: RightIDKey = \PostTagPivot.tagId
}

extension PostTagPivot: Migration {
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.postId)
            builder.field(for: \.tagId)
            builder.reference(from: \.postId, to: \Post.id, onUpdate: nil, onDelete: .cascade)
            builder.reference(from: \.tagId, to: \Tag.id, onUpdate: nil, onDelete: .cascade)
        }
    }
}