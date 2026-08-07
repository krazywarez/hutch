import Foundation
import Testing
@testable import Hutch

@MainActor
struct ProjectFormTests {
    @Test
    func parsesTagsSplittingAndTrimming() {
        #expect(ProjectFormSheet.parseTags("swift, ios ,  ") == ["swift", "ios"])
        #expect(ProjectFormSheet.parseTags("a,b,c") == ["a", "b", "c"])
    }

    @Test
    func parseTagsDeduplicatesCaseInsensitively() {
        #expect(ProjectFormSheet.parseTags("Swift, swift, SWIFT") == ["Swift"])
    }

    @Test
    func parseTagsEmptyInputYieldsEmpty() {
        #expect(ProjectFormSheet.parseTags("   ").isEmpty)
        #expect(ProjectFormSheet.parseTags("").isEmpty)
    }

    @Test
    func linkableResourceDisplayNameCombinesOwnerAndName() {
        let resource = LinkableResource(rid: "r1", name: "hutch", ownerCanonicalName: "~alice", kind: .source)
        #expect(resource.displayName == "~alice/hutch")
        #expect(resource.id == "r1")
    }

    @Test
    func discoveredProjectIDMatchesProject() {
        let project = Project(
            metadata: .init(id: "p1", name: "Hutch", description: nil, website: nil, visibility: .publicVisibility, tags: [], updated: .now),
            resources: .init(mailingLists: [], sources: [], trackers: [], isFullyLoaded: false)
        )
        let discovered = DiscoveredProject(project: project, ownerCanonicalName: "~alice")
        #expect(discovered.id == "p1")
    }
}
