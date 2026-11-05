import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @State private var account = AccountController.shared
    @State private var showSignOutChoices = false
    @State private var showDeleteConfirm = false
    @State private var exportURL: URL?
    @State private var showExporter = false

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.45)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    PosterText(text: "Profile", size: 38)
                    headerCard

                    if account.isSignedIn {
                        SectionLabel(text: "Sync")
                        syncCard
                    }

                    SectionLabel(text: "On this phone")
                    countsCard

                    if !account.isSignedIn {
                        SectionLabel(text: "Sign in")
                        HairlineCard {
                            SignInButtons(
                                busy: account.isBusy,
                                onGoogle: { Task { await account.signInGoogle() } },
                                onApple: { Task { await account.signInApple() } }
                            )
                        }
                    }

                    SectionLabel(text: "History")
                    exportCard

                    if account.isSignedIn {
                        SectionLabel(text: "Sign out")
                        signOutButton
                        deleteButton
                    }

                    if let err = account.lastError, !err.isEmpty {
                        Text(err)
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.emberSoft)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .navigationBarHidden(true)
        .onAppear {
            account.configure(modelContext: modelContext, appModel: model)
        }
        .confirmationDialog("Sign out", isPresented: $showSignOutChoices, titleVisibility: .visible) {
            Button("Keep runs on this phone") {
                Task { await account.signOut(removeLocal: false) }
            }
            Button("Remove runs from this phone", role: .destructive) {
                Task { await account.signOut(removeLocal: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your cloud profile stays either way. Choose whether this phone keeps its local copy.")
        }
        .confirmationDialog("Delete profile?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete profile and synced data", role: .destructive) {
                Task { await account.deleteProfile() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your cloud profile and synced runs. The copy on this phone stays until you delete the app.")
        }
        .alert("Merge history?", isPresented: Binding(
            get: { account.needsMergeDecision },
            set: { if !$0 { account.needsMergeDecision = false } }
        )) {
            Button("Add phone runs to profile") {
                Task { await account.resolveMerge(.keepLocalAndUpload) }
            }
            Button("Use cloud, clear phone", role: .destructive) {
                Task { await account.resolveMerge(.takeCloudAndWipeLocal) }
            }
            Button("Cancel", role: .cancel) {
                account.needsMergeDecision = false
            }
        } message: {
            Text(account.mergeMessage)
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private var headerCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(account.isSignedIn ? (account.displayName?.nilIfEmpty ?? "Signed in") : "On this phone only")
                    .font(Theme.font(size: 22, weight: .black))
                if let subtitle = account.profileSubtitle {
                    Text(subtitle)
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var syncCard: some View {
        HairlineCard {
            HStack(spacing: 12) {
                Image(systemName: syncSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.emberSoft)
                    .frame(width: 28, height: 28)
                Text(syncLabel)
                    .font(Theme.font(size: 15, weight: .semibold))
                Spacer()
                if account.isBusy || account.syncStatus == .syncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var syncSymbol: String {
        switch account.syncStatus {
        case .idle: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .error: return "exclamationmark.icloud.fill"
        }
    }

    private var syncLabel: String {
        switch account.syncStatus {
        case .idle: return "Synced now"
        case .syncing: return "Syncing…"
        case .error(let message): return message
        }
    }

    private var countsCard: some View {
        HairlineCard {
            HStack {
                countTile(title: "Runs", value: "\(account.workoutCount())")
                countTile(title: "PBs", value: "\(PersonalBestStore.shared.allBadges.count)")
            }
        }
    }

    private func countTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.font(size: 28, weight: .black))
            Text(title.uppercased())
                .font(Theme.label(10, .bold))
                .tracking(1)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exportCard: some View {
        HairlineCard {
            Button {
                do {
                    exportURL = try account.exportHistory()
                    showExporter = true
                } catch {
                    account.lastError = error.localizedDescription
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.emberSoft)
                    Text("Export history")
                        .font(Theme.font(size: 15, weight: .bold))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var signOutButton: some View {
        Button("Sign out") { showSignOutChoices = true }
            .buttonStyle(RallyButtonStyle())
            .disabled(account.isBusy)
    }

    private var deleteButton: some View {
        Button("Delete profile and synced data", role: .destructive) {
            showDeleteConfirm = true
        }
        .font(Theme.font(size: 14, weight: .bold))
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(Theme.emberSoft)
        .disabled(account.isBusy)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
