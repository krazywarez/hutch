import SwiftUI

struct UserProfileView: View {
    let user: User

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

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
                if let userType = user.userType {
                    LabeledContent("User Type", value: userType)
                }
                if let pronouns = user.pronouns {
                    LabeledContent("Pronouns", value: pronouns)
                }
                if let suspensionNotice = user.suspensionNotice {
                    LabeledContent("Suspension Notice", value: suspensionNotice)
                }
            }

            Section {
                LabeledContent("Email", value: user.email)
                if let urlString = user.url, let url = URL(string: urlString) {
                    LabeledContent("URL") {
                        Link(urlString, destination: url)
                    }
                }
                if let location = user.location {
                    LabeledContent("Location", value: location)
                }
            }

            if let bio = user.bio {
                Section("Bio") {
                    Text(bio)
                }
            }

            if user.created != nil || user.updated != nil {
                Section {
                    if let created = user.created {
                        LabeledContent("Joined", value: formattedTimestamp(created))
                    }
                    if let updated = user.updated {
                        LabeledContent("Updated", value: formattedTimestamp(updated))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(user.canonicalName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedTimestamp(_ value: String) -> String {
        guard let date = Self.iso8601Formatter.date(from: value) else {
            return value
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
