//
//  CoreDependency.swift
//  Memora
//
//  Core 契約: Core 内部の依存管理
//  Core/Services / Core/Persistence 間の依存を定義
//

// MARK: - Core 契約バージョン

// MARK: - Core 契約バージョン

/// Core 契約のバージョン情報
public enum CoreContractVersion {
    /// 現在のバージョン
    public static let current = "1.0.0"

    /// Protocol バージョン
    public static let protocolVersion = "1.0"

    /// DTO バージョン
    public static let dtoVersion = "1.0"

    /// Error バージョン
    public static let errorVersion = "1.0"
}

// MARK: - 契約整合性チェック

/// Core 契約の整合性をチェックする
public final class CoreContractValidator {
    /// Feature 側の依存が許可されているかチェック
    public static func validate(featureAgent: String, dependency: String) -> Bool {
        switch featureAgent {
        case "files-agent":
            return DependencyPermissionMatrix.filesAgent.contains(dependency)
        case "detail-agent":
            return DependencyPermissionMatrix.detailAgent.contains(dependency)
        case "workspace-agent":
            return DependencyPermissionMatrix.workspaceAgent.contains(dependency)
        default:
            return false
        }
    }

    /// 禁止されている依存かチェック
    public static func isForbidden(dependency: String) -> Bool {
        DependencyPermissionMatrix.forbidden.contains(dependency)
    }
}

