import Foundation

/// A per-repository deploy key (git.sr.ht `SSHKey` under `Repository.deployKeys`).
struct RepositoryDeployKey: Decodable, Sendable, Identifiable, Hashable {
    let rid: String
    let keyType: String
    let fingerprintSHA256: String
    let comment: String?
    let access: AccessMode

    var id: String { rid }
}

private struct DeployKeysQueryResponse: Decodable, Sendable {
    let repository: DeployKeysRepository?
}

private struct DeployKeysRepository: Decodable, Sendable {
    let deployKeys: DeployKeysPage
}

private struct DeployKeysPage: Decodable, Sendable {
    let results: [RepositoryDeployKey]
}

/// `createDeployKey`'s response returns an empty `access` (the stored value is
/// correct — the list query reports it), so we select only `rid` here and let
/// callers reload rather than decode the partial key.
private struct CreateDeployKeyResponse: Decodable, Sendable {}

/// Delete returns the removed key; only success matters here.
private struct DeleteDeployKeyResponse: Decodable, Sendable {}

/// Deploy keys are a git.sr.ht capability (`createDeployKey` / `deleteDeployKey`),
/// owner-only, alongside repository ACLs.
struct RepositoryDeployKeyService: Sendable {
    private let client: SRHTClient

    init(client: SRHTClient) {
        self.client = client
    }

    func fetchDeployKeys(repositoryRid: String) async throws -> [RepositoryDeployKey] {
        let response = try await client.execute(
            service: .git,
            query: Self.deployKeysQuery,
            variables: ["rid": repositoryRid],
            responseType: DeployKeysQueryResponse.self
        )
        return response.repository?.deployKeys.results ?? []
    }

    func createDeployKey(repositoryRid: String, mode: AccessMode, key: String) async throws {
        _ = try await client.execute(
            service: .git,
            query: Self.createDeployKeyMutation,
            variables: ["repo": repositoryRid, "mode": mode.rawValue, "key": key],
            responseType: CreateDeployKeyResponse.self
        )
    }

    func deleteDeployKey(rid: String) async throws {
        _ = try await client.execute(
            service: .git,
            query: Self.deleteDeployKeyMutation,
            variables: ["rid": rid],
            responseType: DeleteDeployKeyResponse.self
        )
    }
}

private extension RepositoryDeployKeyService {
    static let deployKeysQuery = """
    query repositoryDeployKeys($rid: ID!) {
        repository(rid: $rid) {
            deployKeys {
                results {
                    rid
                    keyType
                    fingerprintSHA256
                    comment
                    access
                }
            }
        }
    }
    """

    static let createDeployKeyMutation = """
    mutation createDeployKey($repo: ID!, $mode: AccessMode!, $key: String!) {
        createDeployKey(repo: $repo, mode: $mode, key: $key) { rid }
    }
    """

    static let deleteDeployKeyMutation = """
    mutation deleteDeployKey($rid: ID!) {
        deleteDeployKey(rid: $rid) { rid }
    }
    """
}
