//
//  MainTabView.swift
//  SharedVisions
//
//  Created by Joseph Simpson on 3/16/26.
//

import SwiftUI

struct MainTabView: View {
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
    }
}

#Preview(windowStyle: .automatic) {
    MainTabView()
        .environment(AppModel())
}
