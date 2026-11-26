/// Erreurs métier typées (docs/architecture.md § 4).
public enum DomainError: Error, Sendable, Equatable {
    case notAuthenticated
    case quotaExceeded
    case consentRequired
    case premiumRequired
    case offline
    case notFound
    case validation(String)
}
