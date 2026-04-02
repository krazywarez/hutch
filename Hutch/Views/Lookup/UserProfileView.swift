import SwiftUI

struct UserProfileView: View {
    let user: User

    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if let avatarURL = user.avatar.flatMap(URL.init(string:)) {
                Section {
                    HStack {
                        Spacer()
                        AsyncImage(url: avatarURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.secondary)
                                    .padding(20)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                LabeledContent("Username", value: user.username)
                LabeledContent("Canonical Name", value: user.canonicalName)
                LabeledContent("Email", value: user.email)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(user.canonicalName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
