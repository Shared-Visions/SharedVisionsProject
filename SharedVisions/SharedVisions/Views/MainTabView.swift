//
//  MainTabView.swift
//  SharedVisions
//
//  Created by Joseph Simpson on 3/16/26.
//

import SwiftUI

struct MainTabView: View {

    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                ContentView()
            }
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("About", systemImage: "info.circle") {
                AboutView()
            }
        }
        .ornament(attachmentAnchor: .scene(.bottomTrailing), ornament: {
            if(appModel.useDebugMode) {
                ToggleDebugWindowButton()
            } else {
                EmptyView()
            }
        })
    }
}

#Preview(windowStyle: .automatic) {
    MainTabView()
        .environment(AppModel())
}
