import Foundation

enum ChatScope: Equatable, Hashable, Sendable {
    case file(fileId: UUID)
    case project(projectId: UUID)
    case global
}
