//
//  PlayerView.swift
//  SharedVisions
//
//  Minimal player launcher tab. All playback chrome lives on the
//  in-space PlayerControlBar — this tab only gets an experience loaded
//  (file open or LAN live-connect) and one button into the space.
//

import SwiftUI
import UniformTypeIdentifiers
import ChapterScript
import ChapterPlayer

struct PlayerView: View {
    @Environment(PlayerModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var showingFileImporter = false

    var body: some View {
        ZStack {
            VStack(spacing: 26) {
                Spacer()

                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("ChapterScript Player")
                        .font(.title2.weight(.semibold))
                    Text(statusLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // THE button. Opens the space and plays the loaded
                // document's default sequence; the in-space control bar
                // takes it from there.
                Button {
                    Task {
                        await appModel.playDefaultSequence()
                        if appModel.loadedExperience == nil {
                            await appModel.transitionToPhase("immersive")
                        }
                    }
                } label: {
                    Label("Enter Player", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.immersiveSpaceState != .closed)

                HStack(spacing: 14) {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Open Project…", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    LiveModeView()
                }

                Spacer()
            }
            .padding(32)

            if appModel.isLoadingLiveExperience {
                LiveLoadingOverlay(prefetchProgress: appModel.livePrefetchProgress)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.isLoadingLiveExperience)
        .task {
            // Hand the core the space actions from a view that has them —
            // transitionToPhase("immersive"/"idle") is a no-op until then.
            if appModel.openSpace == nil {
                appModel.openSpace = { id in await openImmersiveSpace(id: id) }
            }
            if appModel.dismissSpace == nil {
                appModel.dismissSpace = { await dismissImmersiveSpace() }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType("com.maestrovision.chapterscript") ?? .directory, .directory],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                // Scope lifetime is owned by PlayerModel for the whole
                // session — playback streams bundle media lazily.
                Task { await appModel.openLocalBundle(url) }
            }
        }
    }

    private var statusLine: String {
        if let document = appModel.loadedExperience?.document {
            let name = document.displayName.isEmpty ? document.id : document.displayName
            let count = document.sequences.count
            return "\(name) · \(count) sequence\(count == 1 ? "" : "s")"
        }
        return "Open a .chapterscript project or connect to Maestro Studio"
    }
}
