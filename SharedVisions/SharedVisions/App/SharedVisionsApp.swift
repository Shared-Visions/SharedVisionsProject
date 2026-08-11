//
//  SharedVisionsApp.swift
//  SharedVisions
//
//  Created by Jeffrey Berthiaume on 3/6/26.
//

import SwiftUI
import ChapterPlayer

@main
struct SharedVisionsApp: App {

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var appModel = AppModel()
    @State private var playerModel = PlayerModel()
    /// Mirror of `playerModel.immersionStyle` for the chapter space's
    /// `.immersionStyle(selection:)` — refreshed via `immersionRevision`
    /// (ImmersionStyle isn't Equatable, so the core publishes a pulse).
    @State private var chapterImmersion: ImmersionStyle = .full

    var body: some Scene {
        // The main window that users will see when they launch the app
        // Provides the entrance to the main story experience.
        // Provides access to the content library.
        WindowGroup (id: appModel.mainWindowID){
            MainTabView()
            .environment(appModel)
            .environment(playerModel)
            .onAppear {
                appModel.mainWindowState = .open
            }
            .onDisappear {
                appModel.mainWindowState = .closed
            }
        }
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)

        // A utility window for development only
        WindowGroup (id: appModel.debugWindowID){
            DebugView()
                .environment(appModel)
                .onAppear {
                    appModel.debugWindowState = .open
                }
                .onDisappear {
                    appModel.debugWindowState = .closed
                }
        }
        .defaultSize(width: 600, height: 400)
        .defaultWindowPlacement { _, context in
            return WindowPlacement(.utilityPanel)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        // The ChapterScript player space: everything a Maestro-authored
        // .chapterscript document mounts (entities, video panels,
        // skybox backdrops) lives under this space's scene root.
        ImmersiveSpace(id: PlayerModel.chapterSpaceID) {
            ChapterImmersiveView()
                .environment(playerModel)
                .onAppear {
                    playerModel.immersiveSpaceState = .open
                    chapterImmersion = playerModel.immersionStyle
                    // The player IS the app while the space is up — the
                    // launcher window gets out of the way and returns
                    // when the session ends.
                    dismissWindow(id: appModel.mainWindowID)
                }
                .onDisappear {
                    playerModel.immersiveSpaceState = .closed
                    openWindow(id: appModel.mainWindowID)
                }
                .onChange(of: playerModel.immersionRevision) {
                    chapterImmersion = playerModel.immersionStyle
                }
        }
        // Both .full and .mixed so sequences can flip between skybox
        // immersion and passthrough placement without a dismiss/reopen.
        .immersionStyle(selection: $chapterImmersion, in: .full, .mixed)
        .defaultLaunchBehavior(.suppressed)

        // An immersive space for the main story
        ImmersiveSpace(id: appModel.mainStorySpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.mainStorySpaceState = .open
                }
                .onDisappear {
                    appModel.mainStorySpaceState = .closed
                }
        }
        .immersionStyle(selection: $appModel.progressiveSpaceRange, in: .progressive)
        .defaultLaunchBehavior(.suppressed)
    }
}
