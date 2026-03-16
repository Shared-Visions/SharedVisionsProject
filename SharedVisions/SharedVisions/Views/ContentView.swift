//
//  ContentView.swift
//  SharedVisions
//
//  Created by Jeffrey Berthiaume on 3/6/26.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            Text("Shared Visions")

            ToggleImmersiveSpaceButton()
        }
        .padding()
        .ornament(attachmentAnchor: .scene(.bottomTrailing), ornament: {
            ToggleDebugWindowButton()
        })
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
