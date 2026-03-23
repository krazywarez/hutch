import SwiftUI
import UIKit

struct BuildTaskLogView: View {
    let task: BuildTask
    let viewModel: BuildDetailViewModel

    var body: some View {
        Group {
            if viewModel.loadingTaskLogs.contains(task.logCacheKey) {
                SRHTLoadingStateView(message: "Loading log…")
            } else if let logText = viewModel.taskLogs[task.logCacheKey] {
                GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal]) {
                        Text(logText)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                            .padding()
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: logText)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            UIPasteboard.general.string = logText
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .accessibilityLabel("Copy log to clipboard")
                    }
                }
            } else if task.log == nil {
                ContentUnavailableView(
                    "No Log",
                    systemImage: "doc.text",
                    description: Text("This task has no log output.")
                )
            } else {
                SRHTLoadingStateView(message: "Loading log…")
            }
        }
        .navigationTitle(task.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTaskLog(task: task)
        }
    }
}
