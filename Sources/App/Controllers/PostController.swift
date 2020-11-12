import FluentMySQL
import Vapor

final class PostController {
    func getRecentPosts_PostResource(_ req: Request) throws -> Future<[PostResource]> {
        let postService: PostService = try req.make(PostService.self)

        return req.withPooledConnection(to: .mysql) { (conn: MySQLConnection) -> Future<[PostResource]> in
            let futurePost: Future<[Post]> = try postService.getRecentPosts_Lazy(conn: conn)

            return futurePost.map { (posts: [Post]) -> [PostResource] in
                return posts.map { (post: Post) -> PostResource in
                    return PostResource(post)
                }
            }
        }
    }

    func getRecentPosts_PostExtendResource_fetchAfter(_ req: Request) throws -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> {
        let postService: PostService = try req.make(PostService.self)

        return req.withPooledConnection(to: .mysql) { (conn: MySQLConnection) -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> in
            let futurePost: Future<[Post]> = try postService.getRecentPosts_Lazy(conn: conn)

            return futurePost.flatMap { (posts: [Post]) -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> in
                return Future.whenAll(posts.map { post -> Future<PostExtendResource<StatusResource, AuthorResource, TagResource>> in
                    let futurePostStatus: Future<Status> = post.status.get(on: conn)
                    let futurePostAuthor: Future<Author> = post.author.get(on: conn)

                    return map(futurePostStatus, futurePostAuthor) { (status: Status, author: Author) -> PostExtendResource<StatusResource, AuthorResource, TagResource> in
                        return PostExtendResource(
                                post,
                                status: StatusResource(status),
                                author: AuthorResource(author),
                                tags: nil
                        )
                    }
                }, eventLoop: req.eventLoop)
            }
        }
    }

    func getRecentPosts_PostExtendResource_fetchJoin(_ req: Request) throws -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> {
        let postService: PostService = try req.make(PostService.self)

        return req.withPooledConnection(to: .mysql) { (conn: MySQLConnection) -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> in
            let futurePostTuple: Future<[(Post, Status, Author)]> = try postService.getRecentPosts_Eager(conn: conn)

            return futurePostTuple.map { (tuples: [(Post, Status, Author)]) -> [PostExtendResource<StatusResource, AuthorResource, TagResource>] in
                return tuples.map { post, status, author -> PostExtendResource<StatusResource, AuthorResource, TagResource> in
                    return PostExtendResource(
                            post,
                            status: StatusResource(status),
                            author: AuthorResource(author),
                            tags: nil
                    )
                }
            }
        }
    }

    func writePost(_ req: Request) throws -> Future<CommonResource> {
        let postService: PostService = try req.make(PostService.self)
        let authorService: AuthorService = try req.make(AuthorService.self)

        let userId = try AuthMiddleware.getAuthHeader(req)

        return req.withPooledConnection(to: .mysql) { (conn: MySQLConnection) -> Future<CommonResource> in
            return try req.content.decode(WritePostRequest.self).flatMap { (body: WritePostRequest) -> Future<CommonResource> in
                let futureAuthor: Future<Author> = try authorService.getAuthorByUserId(conn: conn, userId: userId)

                return futureAuthor.flatMap { (author: Author) -> Future<CommonResource> in
                    guard let authorId: Author.ID = author.id else {
                        throw AuthorError.notFound
                    }

                    let futureResult: Future<Bool> = try postService.writePost(
                            conn: conn,
                            authorId: authorId,
                            title: body.title,
                            text: body.text
                    )

                    return futureResult.map { (result: Bool) -> CommonResource in
                        return CommonResource(code: Int(result), message: CommonResource.CommonMessage.success.rawValue)
                    }
                }
            }
        }
    }

    func getDrafts(_ req: Request) throws -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> {
        let postService: PostService = try req.make(PostService.self)
        let authorService: AuthorService = try req.make(AuthorService.self)

        let userId = try AuthMiddleware.getAuthHeader(req)

        return req.withPooledConnection(to: .mysql) { (conn: MySQLConnection) -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> in
            let futureAuthor: Future<Author> = try authorService.getAuthorByUserId(conn: conn, userId: userId)

            return futureAuthor.flatMap { (author: Author) -> Future<[PostExtendResource<StatusResource, AuthorResource, TagResource>]> in
                guard let authorId: Author.ID = author.id else {
                    throw AuthorError.notFound
                }

                let futurePostTuple: Future<[(Post, Status, Author)]> = try postService.getDrafts(conn: conn, authorId: authorId)

                return futurePostTuple.map { (tuples: [(Post, Status, Author)]) -> [PostExtendResource<StatusResource, AuthorResource, TagResource>] in
                    return tuples.map { post, status, author -> PostExtendResource<StatusResource, AuthorResource, TagResource> in
                        return PostExtendResource(
                                post,
                                status: StatusResource(status),
                                author: AuthorResource(author),
                                tags: nil
                        )
                    }
                }
            }
        }
    }

    func writeDraft(_ req: Request) throws -> Future<CommonResource> {
        let postService: PostService = try req.make(PostService.self)
        let authorService: AuthorService = try req.make(AuthorService.self)

        let userId = try AuthMiddleware.getAuthHeader(req)

        return req.withPooledConnection(to: .mysql) { (conn: MySQLConnection) -> Future<CommonResource> in
            return try req.content.decode(WriteDraftRequest.self).flatMap { (body: WriteDraftRequest) -> Future<CommonResource> in
                let futureAuthor: Future<Author> = try authorService.getAuthorByUserId(conn: conn, userId: userId)

                return futureAuthor.flatMap { (author: Author) -> Future<CommonResource> in
                    guard let authorId: Author.ID = author.id else {
                        throw AuthorError.notFound
                    }

                    let futureResult: Future<Bool> = try postService.writeDraft(
                            conn: conn,
                            authorId: authorId,
                            title: body.title,
                            text: body.text
                    )

                    return futureResult.map { (result: Bool) -> CommonResource in
                        return CommonResource(code: Int(result), message: CommonResource.CommonMessage.success.rawValue)
                    }
                }
            }
        }
    }
}