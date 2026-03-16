//
//  ImmersiveView.swift
//  SharedVisions
//
//  Created by Jeffrey Berthiaume on 3/6/26.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    @State var debug = Entity()

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            guard let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) else { return }
            content.add(scene)

            debug.position = SIMD3<Float>(0.75, 0.25, -1.25)
            let attachment = ViewAttachmentComponent(rootView: ToggleDebugWindowButton())
            debug.components.set(attachment)
            debug.components.set(BillboardComponent())
            scene.addChild(debug)


        }
        .onChange(of: appModel.useDebugMode) { _, newValue in
            if(newValue) {
                print("Debug mode is on")
                debug.isEnabled = true
            } else {
                print("Debug mode is off")
                debug.isEnabled = false
            }
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
