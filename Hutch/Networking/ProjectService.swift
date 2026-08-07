import Foundation

private struct ProjectPageResponse: Decodable, Sendable {
    let me: ProjectPageUser
}

private struct ProjectPageUser: Decodable, Sendable {
    let projects: ProjectPage
}

private struct ProjectPage: Decodable, Sendable {
    let results: [ProjectSummaryPayload]
    let cursor: String?

    private enum CodingKeys: String, CodingKey {
        case results
        case cursor
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([ProjectSummaryPayload].self, forKey: .results) ?? []
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
    }
}

private struct ProjectSummaryPayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let website: String?
    let visibility: Visibility
    let tags: [String]
    let updated: Date

    private enum CodingKeys: String, CodingKey {
        case rid
        case name
        case description
        case website
        case visibility
        case tags
        case updated
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        updated = try container.decodeIfPresent(Date.self, forKey: .updated) ?? .distantPast
    }
}

private struct ProjectDetailResponse: Decodable, Sendable {
    let project: ProjectDetailPayload?
}

private struct ProjectDetailPayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let website: String?
    let visibility: Visibility
    let tags: [String]
    let updated: Date
    let mailingLists: ProjectMailingListPage
    let sources: ProjectSourcePage
    let trackers: ProjectTrackerPage

    private enum CodingKeys: String, CodingKey {
        case rid
        case name
        case description
        case website
        case visibility
        case tags
        case updated
        case mailingLists
        case sources
        case trackers
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        updated = try container.decodeIfPresent(Date.self, forKey: .updated) ?? .distantPast
        mailingLists = try container.decodeIfPresent(ProjectMailingListPage.self, forKey: .mailingLists) ?? .empty
        sources = try container.decodeIfPresent(ProjectSourcePage.self, forKey: .sources) ?? .empty
        trackers = try container.decodeIfPresent(ProjectTrackerPage.self, forKey: .trackers) ?? .empty
    }
}

private struct ProjectMailingListPage: Decodable, Sendable {
    let results: [ProjectMailingListPayload]
    let cursor: String?

    static let empty = ProjectMailingListPage(results: [], cursor: nil)
}

private struct ProjectMailingListPayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let visibility: Visibility
    let owner: Entity

    private enum CodingKeys: String, CodingKey {
        case rid
        case name
        case description
        case visibility
        case owner
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        owner = try container.decodeIfPresent(Entity.self, forKey: .owner) ?? Entity(canonicalName: "~unknown")
    }
}

private struct ProjectSourcePage: Decodable, Sendable {
    let results: [ProjectSourcePayload]
    let cursor: String?

    static let empty = ProjectSourcePage(results: [], cursor: nil)
}

private struct ProjectSourcePayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let visibility: Visibility
    let owner: Entity
    let repoType: Project.SourceRepo.RepoType

    private enum CodingKeys: String, CodingKey {
        case rid
        case name
        case description
        case visibility
        case owner
        case repoType
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        owner = try container.decodeIfPresent(Entity.self, forKey: .owner) ?? Entity(canonicalName: "~unknown")
        repoType = try container.decodeIfPresent(Project.SourceRepo.RepoType.self, forKey: .repoType) ?? .git
    }
}

private struct ProjectTrackerPage: Decodable, Sendable {
    let results: [ProjectTrackerPayload]
    let cursor: String?

    static let empty = ProjectTrackerPage(results: [], cursor: nil)
}

private struct ProjectTrackerPayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let visibility: Visibility
    let owner: Entity

    private enum CodingKeys: String, CodingKey {
        case rid
        case name
        case description
        case visibility
        case owner
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        owner = try container.decodeIfPresent(Entity.self, forKey: .owner) ?? Entity(canonicalName: "~unknown")
    }
}

/// A public project surfaced by discovery, carrying its owner for display.
struct DiscoveredProject: Identifiable, Hashable, Sendable {
    let project: Project
    let ownerCanonicalName: String

    var id: String { project.id }
}

struct DiscoveredProjectsPage: Sendable {
    let projects: [DiscoveredProject]
    let cursor: String?
}

private struct PublicProjectsResponse: Decodable, Sendable {
    let projects: PublicProjectPage
}

private struct PublicProjectPage: Decodable, Sendable {
    let results: [PublicProjectPayload]
    let cursor: String?

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey { case results, cursor }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([PublicProjectPayload].self, forKey: .results) ?? []
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
    }
}

private struct PublicProjectPayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let website: String?
    let visibility: Visibility
    let tags: [String]
    let updated: Date
    let owner: Entity

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey {
            case rid, name, description, website, visibility, tags, updated, owner
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        updated = try container.decodeIfPresent(Date.self, forKey: .updated) ?? .distantPast
        owner = try container.decodeIfPresent(Entity.self, forKey: .owner) ?? Entity(canonicalName: "~unknown")
    }
}

/// A resource the current user can link to a project (#15 add flow).
struct LinkableResource: Identifiable, Hashable, Sendable {
    enum Kind: Sendable { case source, tracker, mailingList }

    let rid: String
    let name: String
    let ownerCanonicalName: String
    let kind: Kind

    var id: String { rid }
    var displayName: String { "\(ownerCanonicalName)/\(name)" }
}

private struct CandidatePayload: Decodable, Sendable {
    let rid: String
    let name: String
    let owner: Entity?
}

private struct CandidatePage: Decodable, Sendable {
    let results: [CandidatePayload]
    let cursor: String?

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey { case results, cursor }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([CandidatePayload].self, forKey: .results) ?? []
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
    }
}

private struct RepoCandidatesResponse: Decodable, Sendable {
    let repositories: CandidatePage
}

private struct TrackerCandidatesResponse: Decodable, Sendable {
    let trackers: CandidatePage
}

private struct ListSubscriptionPayload: Decodable, Sendable {
    let list: CandidatePayload?
}

private struct ListSubscriptionPage: Decodable, Sendable {
    let results: [ListSubscriptionPayload]
    let cursor: String?

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey { case results, cursor }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([ListSubscriptionPayload].self, forKey: .results) ?? []
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
    }
}

private struct ListCandidatesResponse: Decodable, Sendable {
    let subscriptions: ListSubscriptionPage
}

/// Link/unlink mutations only need success; the returned resource is ignored.
private struct LinkMutationResponse: Decodable, Sendable {}

private struct CreateProjectResponse: Decodable, Sendable {
    let createProject: MutatedProjectPayload?
}

private struct UpdateProjectResponse: Decodable, Sendable {
    let updateProject: MutatedProjectPayload?
}

private struct MutatedProjectPayload: Decodable, Sendable {
    let rid: String
    let name: String
    let description: String?
    let website: String?
    let visibility: Visibility
    let tags: [String]
    let updated: Date

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey {
            case rid, name, description, website, visibility, tags, updated
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rid = try container.decode(String.self, forKey: .rid)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .publicVisibility
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        updated = try container.decodeIfPresent(Date.self, forKey: .updated) ?? .distantPast
    }

    var project: Project {
        Project(
            metadata: .init(
                id: rid,
                name: name,
                description: description,
                website: website,
                visibility: visibility,
                tags: tags,
                updated: updated
            ),
            resources: .init(mailingLists: [], sources: [], trackers: [], isFullyLoaded: false)
        )
    }
}

struct ProjectService: Sendable {
    private let client: SRHTClient

    private static let projectsQuery = """
    query meProjects($cursor: Cursor) {
        me {
            projects(cursor: $cursor) {
                results {
                    rid
                    name
                    description
                    website
                    visibility
                    tags
                    updated
                }
                cursor
            }
        }
    }
    """

    private static let projectDetailQuery = """
    query projectDetail($rid: ID!, $mailingListsCursor: Cursor, $sourcesCursor: Cursor, $trackersCursor: Cursor) {
        project(rid: $rid) {
            rid
            name
            description
            website
            visibility
            tags
            updated
            mailingLists(cursor: $mailingListsCursor) {
                results {
                    rid
                    name
                    description
                    visibility
                    owner { canonicalName }
                }
                cursor
            }
            sources(cursor: $sourcesCursor) {
                results {
                    rid
                    name
                    description
                    visibility
                    owner { canonicalName }
                    repoType
                }
                cursor
            }
            trackers(cursor: $trackersCursor) {
                results {
                    rid
                    name
                    description
                    visibility
                    owner { canonicalName }
                }
                cursor
            }
        }
    }
    """

    private static let publicProjectsQuery = """
    query publicProjects($cursor: Cursor) {
        projects(cursor: $cursor) {
            results {
                rid
                name
                description
                website
                visibility
                tags
                updated
                owner { canonicalName }
            }
            cursor
        }
    }
    """

    private static let createProjectMutation = """
    mutation createProject($name: String!, $visibility: Visibility!, $description: String, $tags: [String!]) {
        createProject(name: $name, visibility: $visibility, description: $description, tags: $tags) {
            rid
            name
            description
            website
            visibility
            tags
            updated
        }
    }
    """

    private static let updateProjectMutation = """
    mutation updateProject($rid: ID!, $input: ProjectInput!) {
        updateProject(rid: $rid, input: $input) {
            rid
            name
            description
            website
            visibility
            tags
            updated
        }
    }
    """

    private static func linkMutation(field: String, resourceParam: String) -> String {
        """
        mutation link($projectID: ID!, $resourceID: ID!) {
            \(field)(projectID: $projectID, \(resourceParam): $resourceID) { rid }
        }
        """
    }

    private static let repositoriesCandidatesQuery = """
    query repositories($cursor: Cursor) {
        repositories(cursor: $cursor) {
            results { rid name owner { canonicalName } }
            cursor
        }
    }
    """

    private static let trackersCandidatesQuery = """
    query trackers($cursor: Cursor) {
        trackers(cursor: $cursor) {
            results { rid name owner { canonicalName } }
            cursor
        }
    }
    """

    private static let listCandidatesQuery = """
    query subscriptions($cursor: Cursor) {
        subscriptions(cursor: $cursor) {
            results {
                ... on MailingListSubscription {
                    list { rid name owner { canonicalName } }
                }
            }
            cursor
        }
    }
    """

    init(client: SRHTClient) {
        self.client = client
    }

    func fetchProjects(forceRefresh: Bool = false) async throws -> [Project] {
        try await fetchProjectSummaries(forceRefresh: forceRefresh).map(Self.makeSummaryProject)
    }

    func fetchProjectDetail(rid: String) async throws -> Project {
        try await fetchProjectDetailPayload(rid: rid)
    }

    // MARK: - Discovery (#12)

    /// Lists public projects across all users. Not cached — discovery is
    /// browsed live and paginated by the caller.
    func fetchPublicProjects(cursor: String? = nil) async throws -> DiscoveredProjectsPage {
        var variables: [String: any Sendable] = [:]
        if let cursor {
            variables["cursor"] = cursor
        }

        let response = try await client.execute(
            service: .hub,
            query: Self.publicProjectsQuery,
            variables: variables.isEmpty ? nil : variables,
            responseType: PublicProjectsResponse.self
        )

        let projects = response.projects.results.map { payload in
            DiscoveredProject(
                project: Project(
                    metadata: .init(
                        id: payload.rid,
                        name: payload.name,
                        description: payload.description,
                        website: payload.website,
                        visibility: payload.visibility,
                        tags: payload.tags,
                        updated: payload.updated
                    ),
                    resources: .init(mailingLists: [], sources: [], trackers: [], isFullyLoaded: false)
                ),
                ownerCanonicalName: payload.owner.canonicalName
            )
        }
        return DiscoveredProjectsPage(projects: projects, cursor: response.projects.cursor)
    }

    // MARK: - Mutations (#13, #14, #15)

    func createProject(
        name: String,
        visibility: Visibility,
        description: String?,
        tags: [String]
    ) async throws -> Project {
        var variables: [String: any Sendable] = ["name": name, "visibility": visibility.rawValue]
        if let description, !description.isEmpty {
            variables["description"] = description
        }
        if !tags.isEmpty {
            variables["tags"] = tags
        }

        let response = try await client.execute(
            service: .hub,
            query: Self.createProjectMutation,
            variables: variables,
            responseType: CreateProjectResponse.self
        )
        await invalidateProjectCaches()

        guard let payload = response.createProject else {
            throw SRHTError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing createProject payload"))
            )
        }
        return payload.project
    }

    /// Updates a project. Only non-nil fields are sent; `description`/`website`
    /// pass an empty string to clear the field.
    func updateProject(
        rid: String,
        name: String? = nil,
        description: String? = nil,
        website: String? = nil,
        visibility: Visibility? = nil,
        tags: [String]? = nil
    ) async throws -> Project {
        var input: [String: any Sendable] = [:]
        if let name {
            input["name"] = name
        }
        if let description {
            input["description"] = description
        }
        if let website {
            input["website"] = website
        }
        if let visibility {
            input["visibility"] = visibility.rawValue
        }
        if let tags {
            input["tags"] = tags
        }

        let response = try await client.execute(
            service: .hub,
            query: Self.updateProjectMutation,
            variables: ["rid": rid, "input": input],
            responseType: UpdateProjectResponse.self
        )
        await invalidateProjectCaches()

        guard let payload = response.updateProject else {
            throw SRHTError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing updateProject payload"))
            )
        }
        return payload.project
    }

    func linkSource(projectID: String, sourceRepoID: String) async throws {
        try await runLink(field: "linkSource", resourceParam: "sourceRepoID", projectID: projectID, resourceID: sourceRepoID)
    }

    func unlinkSource(projectID: String, sourceRepoID: String) async throws {
        try await runLink(field: "unlinkSource", resourceParam: "sourceRepoID", projectID: projectID, resourceID: sourceRepoID)
    }

    func linkTracker(projectID: String, trackerID: String) async throws {
        try await runLink(field: "linkTracker", resourceParam: "trackerID", projectID: projectID, resourceID: trackerID)
    }

    func unlinkTracker(projectID: String, trackerID: String) async throws {
        try await runLink(field: "unlinkTracker", resourceParam: "trackerID", projectID: projectID, resourceID: trackerID)
    }

    func linkMailingList(projectID: String, listID: String) async throws {
        try await runLink(field: "linkMailingList", resourceParam: "listID", projectID: projectID, resourceID: listID)
    }

    func unlinkMailingList(projectID: String, listID: String) async throws {
        try await runLink(field: "unlinkMailingList", resourceParam: "listID", projectID: projectID, resourceID: listID)
    }

    private func runLink(field: String, resourceParam: String, projectID: String, resourceID: String) async throws {
        _ = try await client.execute(
            service: .hub,
            query: Self.linkMutation(field: field, resourceParam: resourceParam),
            variables: ["projectID": projectID, "resourceID": resourceID],
            responseType: LinkMutationResponse.self
        )
        await invalidateProjectCaches()
    }

    private func invalidateProjectCaches() async {
        await client.invalidateCache(prefix: APICacheKeys.prefix(SRHTService.hub.rawValue))
    }

    // MARK: - Linkable resource candidates (#15 add flow)

    /// Repositories the user can link (git and hg), sorted by display name.
    func fetchLinkableSources() async throws -> [LinkableResource] {
        async let git = fetchRepoCandidates(service: .git)
        async let hg = fetchRepoCandidates(service: .hg)
        return dedupeSorted(try await git + (try await hg))
    }

    func fetchLinkableTrackers() async throws -> [LinkableResource] {
        var results: [LinkableResource] = []
        var cursor: String?
        repeat {
            let response = try await client.execute(
                service: .todo,
                query: Self.trackersCandidatesQuery,
                variables: cursor.map { ["cursor": $0] },
                responseType: TrackerCandidatesResponse.self
            )
            results.append(contentsOf: response.trackers.results.map {
                LinkableResource(rid: $0.rid, name: $0.name, ownerCanonicalName: $0.owner?.canonicalName ?? "", kind: .tracker)
            })
            cursor = response.trackers.cursor
        } while cursor != nil
        return dedupeSorted(results)
    }

    func fetchLinkableMailingLists() async throws -> [LinkableResource] {
        var results: [LinkableResource] = []
        var cursor: String?
        repeat {
            let response = try await client.execute(
                service: .lists,
                query: Self.listCandidatesQuery,
                variables: cursor.map { ["cursor": $0] },
                responseType: ListCandidatesResponse.self
            )
            results.append(contentsOf: response.subscriptions.results.compactMap(\.list).map {
                LinkableResource(rid: $0.rid, name: $0.name, ownerCanonicalName: $0.owner?.canonicalName ?? "", kind: .mailingList)
            })
            cursor = response.subscriptions.cursor
        } while cursor != nil
        return dedupeSorted(results)
    }

    private func fetchRepoCandidates(service: SRHTService) async throws -> [LinkableResource] {
        var results: [LinkableResource] = []
        var cursor: String?
        repeat {
            let response = try await client.execute(
                service: service,
                query: Self.repositoriesCandidatesQuery,
                variables: cursor.map { ["cursor": $0] },
                responseType: RepoCandidatesResponse.self
            )
            results.append(contentsOf: response.repositories.results.map {
                LinkableResource(rid: $0.rid, name: $0.name, ownerCanonicalName: $0.owner?.canonicalName ?? "", kind: .source)
            })
            cursor = response.repositories.cursor
        } while cursor != nil
        return results
    }

    private func dedupeSorted(_ items: [LinkableResource]) -> [LinkableResource] {
        var seen = Set<String>()
        return items
            .filter { seen.insert($0.rid).inserted }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func fetchProjectSummaries(forceRefresh: Bool) async throws -> [ProjectSummaryPayload] {
        var results: [ProjectSummaryPayload] = []
        var cursor: String?

        while true {
            var variables: [String: any Sendable] = [:]
            if let cursor {
                variables["cursor"] = cursor
            }

            let cached = try await client.executeCached(
                service: .hub,
                query: Self.projectsQuery,
                variables: variables.isEmpty ? nil : variables,
                responseType: ProjectPageResponse.self,
                cacheKey: APICacheKeys.projects(cursor: cursor),
                resourceType: .userProfile,
                ttl: APICacheTTLs.projectList,
                policy: forceRefresh ? .refreshIgnoringCache : .cacheFirstThenRefresh
            )
            let response = cached.value

            results.append(contentsOf: response.me.projects.results)
            guard let nextCursor = response.me.projects.cursor else {
                break
            }
            cursor = nextCursor
        }

        return results.sorted { $0.updated > $1.updated }
    }

    private func fetchProjectDetailPayload(rid: String) async throws -> Project {
        var mailingLists: [Project.MailingList] = []
        var sources: [Project.SourceRepo] = []
        var trackers: [Project.Tracker] = []
        var mailingListsCursor: String?
        var sourcesCursor: String?
        var trackersCursor: String?

        while true {
            var variables: [String: any Sendable] = ["rid": rid]
            if let mailingListsCursor {
                variables["mailingListsCursor"] = mailingListsCursor
            }
            if let sourcesCursor {
                variables["sourcesCursor"] = sourcesCursor
            }
            if let trackersCursor {
                variables["trackersCursor"] = trackersCursor
            }

            let cached = try await client.executeCached(
                service: .hub,
                query: Self.projectDetailQuery,
                variables: variables,
                responseType: ProjectDetailResponse.self,
                cacheKey: APICacheKeys.projectDetail(
                    rid: rid,
                    mailingListsCursor: mailingListsCursor,
                    sourcesCursor: sourcesCursor,
                    trackersCursor: trackersCursor
                ),
                resourceType: .userProfile,
                ttl: APICacheTTLs.projectDetail,
                policy: .cacheFirstThenRefresh
            )
            let response = cached.value

            guard let project = response.project else {
                throw SRHTError.decodingError(
                    DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing project payload"))
                )
            }

            mailingLists.append(contentsOf: project.mailingLists.results.map {
                Project.MailingList(
                    id: $0.rid,
                    name: $0.name,
                    description: $0.description,
                    visibility: $0.visibility,
                    owner: $0.owner
                )
            })
            sources.append(contentsOf: project.sources.results.map {
                Project.SourceRepo(
                    id: $0.rid,
                    name: $0.name,
                    description: $0.description,
                    visibility: $0.visibility,
                    owner: $0.owner,
                    repoType: $0.repoType
                )
            })
            trackers.append(contentsOf: project.trackers.results.map {
                Project.Tracker(
                    id: $0.rid,
                    name: $0.name,
                    description: $0.description,
                    visibility: $0.visibility,
                    owner: $0.owner
                )
            })

            mailingListsCursor = project.mailingLists.cursor
            sourcesCursor = project.sources.cursor
            trackersCursor = project.trackers.cursor

            if mailingListsCursor == nil, sourcesCursor == nil, trackersCursor == nil {
                return Project(
                    metadata: .init(
                        id: project.rid,
                        name: project.name,
                        description: project.description,
                        website: project.website,
                        visibility: project.visibility,
                        tags: project.tags,
                        updated: project.updated
                    ),
                    resources: .init(
                        mailingLists: deduplicate(mailingLists),
                        sources: deduplicate(sources),
                        trackers: deduplicate(trackers),
                        isFullyLoaded: true
                    )
                )
            }
        }
    }

    private static func makeSummaryProject(from summary: ProjectSummaryPayload) -> Project {
        Project(
            metadata: .init(
                id: summary.rid,
                name: summary.name,
                description: summary.description,
                website: summary.website,
                visibility: summary.visibility,
                tags: summary.tags,
                updated: summary.updated
            ),
            resources: .init(mailingLists: [], sources: [], trackers: [], isFullyLoaded: false)
        )
    }

    private func deduplicate<T: Identifiable & Hashable>(_ items: [T]) -> [T] where T.ID: Hashable {
        var seen = Set<T.ID>()
        return items.filter { item in
            seen.insert(item.id).inserted
        }
    }
}
