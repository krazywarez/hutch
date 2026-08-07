import Foundation
import Testing
@testable import Hutch

@MainActor
struct RepositoryDeployKeyTests {
    @Test
    func decodesDeployKey() throws {
        let json = """
        { "rid": "k1", "keyType": "ssh-ed25519", "fingerprintSHA256": "SHA256:abc", "comment": "laptop", "access": "RW" }
        """
        let key = try JSONDecoder().decode(RepositoryDeployKey.self, from: Data(json.utf8))
        #expect(key.rid == "k1")
        #expect(key.id == "k1")
        #expect(key.access == .rw)
        #expect(key.comment == "laptop")
    }

    @Test
    func decodesDeployKeyWithNullComment() throws {
        let json = """
        { "rid": "k2", "keyType": "ssh-rsa", "fingerprintSHA256": "SHA256:def", "comment": null, "access": "RO" }
        """
        let key = try JSONDecoder().decode(RepositoryDeployKey.self, from: Data(json.utf8))
        #expect(key.comment == nil)
        #expect(key.access == .ro)
    }
}
