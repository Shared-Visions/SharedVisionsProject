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
