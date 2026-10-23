import PhotosUI
import SwiftUI

private let profileBioMarkdownOptions = AttributedString.MarkdownParsingOptions(
    interpretedSyntax: .inlineOnlyPreservingWhitespace
)

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(AppStorageKeys.contributionGraphsEnabled, store: .standard) private var contributionGraphsEnabled = true
    @State private var viewModel: SettingsViewModel?
    @State private var contributionViewModel: UserProfileViewModel?
    @State private var pendingDestructiveAction: ProfileDestructiveAction?

    var body: some View {
        ModelContent(model: viewModel, loadingMessage: "Loading profile…") { profileContent($0) }
        .navigationTitle("Profile")
        .task {
            if viewModel == nil {
                let vm = SettingsViewModel(client: appState.client)
                viewModel = vm
                await vm.loadProfile()
            }
        }
        .task(id: contributionGraphsEnabled ? appState.currentUser?.canonicalName ?? "" : "contributions-disabled") {
            guard contributionGraphsEnabled, let currentUser = appState.currentUser else { return }

            let owner = currentUser.canonicalName.hasPrefix("~")
                ? String(currentUser.canonicalName.dropFirst())
                : currentUser.canonicalName
            let actor = currentUser.canonicalName.hasPrefix("~") ? currentUser.canonicalName : "~\(currentUser.canonicalName)"

            let vm = UserProfileViewModel.reusing(contributionViewModel, owner: owner, actor: actor, appState: appState)
            if vm !== contributionViewModel {
                contributionViewModel = vm
            }

            await vm.loadContributions()
        }
    }

    @ViewBuilder
    private func profileContent(_ viewModel: SettingsViewModel) -> some View {
        Form {
            if let profile = viewModel.profile {
                profileSection(profile, viewModel: viewModel)

                if contributionGraphsEnabled, let contributionViewModel {
                    Section {
                        ContributionProfileCard(
                            actor: contributionViewModel.actor,
                            weeks: contributionViewModel.contributionCalendar.map {
                                ContributionCalendarLayout.weekColumns(from: $0.days)
                            } ?? [],
                            stats: contributionViewModel.contributionStats,
                            isLoading: contributionViewModel.isLoadingContributions,
                            error: contributionViewModel.contributionsError ?? contributionViewModel.contributionStatusText,
                            isIndexedButEmpty: contributionViewModel.isContributionActivityIndexedButEmpty
                        )
                        .themedRow()
                    }
                }

                sshKeysSection(viewModel)
                pgpKeysSection(viewModel)
                patSection(viewModel)
                auditLogSection(viewModel)
            }
        }
        .themedList()
        .overlay {
            SRHTLoadStateView(
                isLoading: viewModel.isLoading,
                error: viewModel.error,
                isEmpty: viewModel.profile == nil,
                loadingMessage: "Loading profile…",
                errorTitle: "Couldn't Load Profile",
                retryAction: { await viewModel.loadProfile() }
            ) {}
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isEditingProfile },
            set: { viewModel.isEditingProfile = $0 }
        )) {
            if let profile = viewModel.profile {
                EditProfileSheet(profile: profile, viewModel: viewModel)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil && viewModel.profile != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.error = nil
                }
            }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .destructiveConfirmation($pendingDestructiveAction) { action in
            switch action {
            case .deleteSSHKey(let key):
                await viewModel.deleteSSHKey(key)
            case .deletePGPKey(let key):
                await viewModel.deletePGPKey(key)
            }
        }
        .refreshable {
            await viewModel.loadProfile()
        }
    }

    @ViewBuilder
    private func profileSection(_ profile: UserProfile, viewModel: SettingsViewModel) -> some View {
        Section("Profile") {
            profileHeader(profile)

            if let bio = profile.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProfileBioView(markdown: bio)
                }
                .themedRow()
            }

            if let location = profile.location, !location.isEmpty {
                LabeledContent("Location", value: location)
                    .themedRow()
            }

            if let url = profile.url, !url.isEmpty {
                LabeledContent("URL", value: url)
                    .themedRow()
            }

            if let status = profile.paymentStatus {
                LabeledContent("Payment", value: status.capitalized)
                    .themedRow()
            }

            subscriptionRows(profile)

            Button("Edit Profile") {
                viewModel.isEditingProfile = true
            }
            .themedRow()

            SRHTShareButton(url: SRHTWebURL.profile(canonicalName: profile.canonicalName), target: .profile) {
                SwiftUI.Label("Share Profile", systemImage: "square.and.arrow.up")
            }
            .themedRow()
        }
    }

    @ViewBuilder
    private func sshKeysSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            ForEach(viewModel.sshKeys) { key in
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.displayLabel)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack {
                        if let comment = key.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(key.created.relativeDescription)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let lastUsed = key.lastUsed {
                        Text("Last used \(lastUsed.relativeDescription)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        pendingDestructiveAction = .deleteSSHKey(key)
                    }
                }
            }
            .themedRow()

            AddKeyControls(
                kind: "SSH",
                systemImage: "key",
                isAdding: Binding(get: { viewModel.isAddingSSHKey }, set: { viewModel.isAddingSSHKey = $0 }),
                key: Binding(get: { viewModel.newSSHKey }, set: { viewModel.newSSHKey = $0 })
            ) {
                await viewModel.addSSHKey()
            }
        } header: {
            Text("SSH Keys")
        } footer: {
            Text("\(viewModel.sshKeys.count) key\(viewModel.sshKeys.count == 1 ? "" : "s")")
        }
    }

    @ViewBuilder
    private func pgpKeysSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            ForEach(viewModel.pgpKeys) { key in
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.fingerprint)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(key.created.relativeDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        pendingDestructiveAction = .deletePGPKey(key)
                    }
                }
            }
            .themedRow()

            AddKeyControls(
                kind: "PGP",
                systemImage: "key.fill",
                isAdding: Binding(get: { viewModel.isAddingPGPKey }, set: { viewModel.isAddingPGPKey = $0 }),
                key: Binding(get: { viewModel.newPGPKey }, set: { viewModel.newPGPKey = $0 })
            ) {
                await viewModel.addPGPKey()
            }
        } header: {
            Text("PGP Keys")
        } footer: {
            Text("\(viewModel.pgpKeys.count) key\(viewModel.pgpKeys.count == 1 ? "" : "s")")
        }
    }

    @ViewBuilder
    private func patSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            if viewModel.isLoadingPATs {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .themedRow()
            } else if viewModel.personalAccessTokens.isEmpty {
                Button("Load Tokens") {
                    Task { await viewModel.loadPersonalAccessTokens() }
                }
                .themedRow()
            } else {
                ForEach(viewModel.personalAccessTokens) { token in
                    PersonalAccessTokenRow(token: token)
                }
                .themedRow()
            }
        } header: {
            Text("Personal Access Tokens")
        } footer: {
            if !viewModel.personalAccessTokens.isEmpty {
                Text("\(viewModel.personalAccessTokens.count) token\(viewModel.personalAccessTokens.count == 1 ? "" : "s")")
            }
        }
    }

    /// Loaded on demand, like the tokens above — an audit log is something you go
    /// looking for, not something worth a request on every profile view.
    @ViewBuilder
    private func auditLogSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            if viewModel.isLoadingAuditLog {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .themedRow()
            } else if let error = viewModel.auditLogError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .themedRow()
            } else if viewModel.auditLog.isEmpty {
                Button("Load Audit Log") {
                    Task { await viewModel.loadAuditLog() }
                }
                .themedRow()
            } else {
                ForEach(viewModel.auditLog) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.eventType)
                            .font(.subheadline)

                        if let details = entry.details, !details.isEmpty {
                            Text(details)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        HStack(spacing: 12) {
                            Text(entry.created.relativeDescription)
                            Text(entry.ipAddress)
                                .monospaced()
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.eventType), \(entry.created.relativeDescription), from \(entry.ipAddress)")
                }
                .themedRow()
            }
        } header: {
            Text("Audit Log")
        } footer: {
            Text("Recent security-relevant activity on your account, newest first. The full log lives on meta.sr.ht.")
        }
    }

    @ViewBuilder
    private func subscriptionRows(_ profile: UserProfile) -> some View {
        if let sub = profile.subscription {
            if let status = sub.status {
                LabeledContent("Subscription", value: status.capitalized)
                    .themedRow()
            }
            if let interval = sub.interval {
                LabeledContent("Interval", value: interval.capitalized)
                    .themedRow()
            }
        }
    }

    @ViewBuilder
    private func profileHeader(_ profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: profile.avatar.flatMap { URL(string: $0) }) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.canonicalName)
                    .font(.headline)
                Text(profile.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let userType = profile.userType {
                    Text(userType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .themedRow()
    }
}

/// A key list's add field and its Cancel and Add buttons, or the button that opens them.
private struct AddKeyControls: View {
    /// "SSH", "PGP".
    let kind: String
    let systemImage: String
    @Binding var isAdding: Bool
    @Binding var key: String
    let add: () async -> Void

    var body: some View {
        if isAdding {
            TextField("Paste \(kind) public key", text: $key, axis: .vertical)
                .font(.caption.monospaced())
                .lineLimit(3...6)
                .themedRow()

            HStack {
                Button("Cancel") {
                    isAdding = false
                    key = ""
                }
                Spacer()
                Button("Add") {
                    Task { await add() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .themedRow()
        } else {
            Button {
                isAdding = true
            } label: {
                SwiftUI.Label("Add \(kind) Key", systemImage: systemImage)
            }
            .themedRow()
        }
    }
}

private struct PersonalAccessTokenRow: View {
    let token: PersonalAccessToken

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(token.comment ?? "Token #\(token.id)")
                    .font(.subheadline)
                Spacer()
            }

            HStack(spacing: 12) {
                Text("Issued \(token.issued.relativeDescription)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let expires = token.expires {
                    Text("Expires \(expires.relativeDescription)")
                        .font(.caption2)
                        .foregroundStyle(expires < Date.now ? .red : .secondary)
                }
            }

            if let grants = token.grants, !grants.isEmpty {
                Text(grants)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }
}

private struct ProfileBioView: View {
    let markdown: String

    var body: some View {
        Text(profileBioAttributedString(markdown))
            .frame(maxWidth: .infinity, alignment: .leading)
            .tint(.accentColor)
            .textSelection(.enabled)
    }
}

func profileBioAttributedString(_ markdown: String) -> AttributedString {
    guard let attributed = try? AttributedString(
        markdown: markdown,
        options: profileBioMarkdownOptions
    ) else {
        return AttributedString(markdown)
    }
    return attributed
}

private struct EditProfileSheet: View {
    let profile: UserProfile
    let viewModel: SettingsViewModel

    @Environment(\.isAMOLEDTheme) private var isAMOLED
    @State private var email: String
    @State private var url: String
    @State private var location: String
    @State private var bio: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarPreview: UIImage?
    @State private var isShowingRemoveAvatarConfirmation = false

    @Environment(\.dismiss) private var dismiss

    init(profile: UserProfile, viewModel: SettingsViewModel) {
        self.profile = profile
        self.viewModel = viewModel
        _email = State(initialValue: profile.email)
        _url = State(initialValue: profile.url ?? "")
        _location = State(initialValue: profile.location ?? "")
        _bio = State(initialValue: profile.bio ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Group {
                                    if let avatarPreview {
                                        Image(uiImage: avatarPreview)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        AsyncImage(url: profile.avatar.flatMap { URL(string: $0) }) { phase in
                                            if case .success(let image) = phase {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } else {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .resizable()
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }

                            Text("Tap to change avatar")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if viewModel.isUploadingAvatar {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(isAMOLED ? Color.black : Color.clear)

                    if profile.avatar != nil || avatarPreview != nil {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                isShowingRemoveAvatarConfirmation = true
                            } label: {
                                Text("Remove Avatar")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isUploadingAvatar)
                            Spacer()
                        }
                        .listRowBackground(isAMOLED ? Color.black : Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                Section("Edit Profile") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .themedRow()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter URL", text: $url)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .themedRow()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter location", text: $location)
                    }
                    .themedRow()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter bio", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .themedRow()
                }
            }
            .themedList()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarPreview = image
                        if let jpegData = image.jpegData(compressionQuality: 0.85) {
                            await viewModel.uploadAvatar(jpegData: jpegData)
                        }
                    }
                }
            }
            .alert("Remove Avatar?", isPresented: $isShowingRemoveAvatarConfirmation) {
                Button("Cancel", role: .cancel) {
                    /* Dismiss only; removal uses the destructive button. */
                }
                Button("Remove Avatar", role: .destructive) {
                    Task {
                        await viewModel.removeAvatar()
                        if viewModel.error == nil {
                            avatarPreview = nil
                            selectedPhoto = nil
                        }
                    }
                }
            } message: {
                Text("Your profile avatar will be removed from SourceHut.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.saveProfile(
                                email: email,
                                url: url,
                                location: location,
                                bio: bio
                            )
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSavingProfile {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSavingProfile)
                }
            }
        }
    }
}

private enum ProfileDestructiveAction: DestructiveAction {
    case deleteSSHKey(SSHKey)
    case deletePGPKey(PGPKey)

    var title: String {
        switch self {
        case .deleteSSHKey:
            "Remove SSH Key?"
        case .deletePGPKey:
            "Remove PGP Key?"
        }
    }

    var confirmationLabel: String {
        switch self {
        case .deleteSSHKey:
            "Remove SSH Key"
        case .deletePGPKey:
            "Remove PGP Key"
        }
    }

    var message: String {
        switch self {
        case .deleteSSHKey(let key):
            "Remove \(key.displayLabel) from your account?"
        case .deletePGPKey(let key):
            "Remove PGP key \(key.fingerprint) from your account?"
        }
    }
}
