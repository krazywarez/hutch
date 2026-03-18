import SwiftUI

struct RepositoryCloneURLs {
    let readOnly: String
    let readWrite: String
}

func repositoryCloneURLs(for repository: RepositorySummary) -> RepositoryCloneURLs {
    let owner = repository.owner.canonicalName
    let name = repository.name

    switch repository.service {
    case .git:
        return RepositoryCloneURLs(
            readOnly: "https://git.sr.ht/\(owner)/\(name)",
            readWrite: "git@git.sr.ht:\(owner)/\(name)"
        )
    case .hg:
        return RepositoryCloneURLs(
            readOnly: "https://hg.sr.ht/\(owner)/\(name)",
            readWrite: "ssh://hg@hg.sr.ht/\(owner)/\(name)"
        )
    default:
        return RepositoryCloneURLs(
            readOnly: "https://\(repository.service.rawValue).sr.ht/\(owner)/\(name)",
            readWrite: ""
        )
    }
}

func repositoryVisibilityLabel(_ visibility: Visibility) -> String {
    switch visibility {
    case .public:
        return "Public"
    case .unlisted:
        return "Unlisted"
    case .private:
        return "Private"
    }
}

struct RepositorySummaryCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct RepositorySummaryField: View {
    let label: String
    let value: String
    var monospace: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospace ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
    }
}

struct RepositorySummaryListRow: View {
    let label: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if values.isEmpty {
                Text("None")
                    .foregroundStyle(.tertiary)
            } else {
                Text(values.joined(separator: ", "))
            }
        }
    }
}
