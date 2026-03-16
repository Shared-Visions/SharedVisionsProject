//
//  SharedVisionsApp.swift
//  SharedVisions
//
//  Created by Jeffrey Berthiaume on 3/6/26.
//

import SwiftUI

@main
struct SharedVisionsApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        // The main window that users will see when they launch the app
        // Provides the entrance to the main story experience.
        // Provides access to the content library.
        WindowGroup (id: appModel.mainWindowID){
            ContentView()
                .environment(appModel)
                .onAppear {
                    appModel.mainWindowState = .open
                }
                .onDisappear {
                    appModel.mainWindowState = .closed
                }
        }

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
    }
}
