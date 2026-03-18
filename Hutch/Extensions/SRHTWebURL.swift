import Foundation

enum SRHTWebURL {
    static func repository(_ repository: RepositorySummary) -> URL? {
        userScopedURL(
            host: "\(repository.service.rawValue).sr.ht",
            ownerCanonicalName: repository.owner.canonicalName,
            pathComponents: [repository.name]
        )
    }

    static func build(jobId: Int, ownerCanonicalName: String) -> URL? {
        userScopedURL(
            host: "builds.sr.ht",
            ownerCanonicalName: ownerCanonicalName,
            pathComponents: ["job", String(jobId)]
        )
    }

    static func tracker(ownerUsername: String, trackerName: String) -> URL? {
        userScopedURL(
            host: "todo.sr.ht",
            ownerUsername: ownerUsername,
            pathComponents: [trackerName]
        )
    }

    static func ticket(ownerUsername: String, trackerName: String, ticketId: Int) -> URL? {
        userScopedURL(
            host: "todo.sr.ht",
            ownerUsername: ownerUsername,
            pathComponents: [trackerName, String(ticketId)]
        )
    }

    static func profile(canonicalName: String) -> URL? {
        userScopedURL(
            host: "meta.sr.ht",
            ownerCanonicalName: canonicalName,
            pathComponents: []
        )
    }

    private static func userScopedURL(
        host: String,
        ownerCanonicalName: String,
        pathComponents: [String]
    ) -> URL? {
        userScopedURL(
            host: host,
            ownerUsername: username(from: ownerCanonicalName),
            pathComponents: pathComponents
        )
    }

    private static func userScopedURL(
        host: String,
        ownerUsername: String,
        pathComponents: [String]
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host

        let encodedComponents = (["~\(ownerUsername)"] + pathComponents).map { pathComponent in
            pathComponent.addingPercentEncoding(withAllowedCharacters: pathComponentCharacterSet) ?? pathComponent
        }
        components.percentEncodedPath = "/" + encodedComponents.joined(separator: "/")
        return components.url
    }

    private static func username(from canonicalName: String) -> String {
        if canonicalName.hasPrefix("~") {
            return String(canonicalName.dropFirst())
        }
        return canonicalName
    }

    private static let pathComponentCharacterSet: CharacterSet = {
        var characterSet = CharacterSet.urlPathAllowed
        characterSet.remove(charactersIn: "/")
        return characterSet
    }()
}
