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

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            guard let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) else { return }
            content.add(scene)

            if(appModel.useDebugMode) {
                let debug = Entity()
                debug.position = SIMD3<Float>(0.75, 0.25, -1.25)
                let attachment = ViewAttachmentComponent(rootView: ToggleDebugWindowButton())
                debug.components.set(attachment)
                debug.components.set(BillboardComponent())
                scene.addChild(debug)
            }

        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
