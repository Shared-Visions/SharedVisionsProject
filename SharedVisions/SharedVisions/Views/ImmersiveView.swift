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
    @State var pointLight: Entity?

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

            if let glassSphere = scene.findEntity(named: "GlassSphere"), let pointLight = scene.findEntity(named: "PointLight") {
                self.pointLight = pointLight
                // Predefined positions in front of the user (x: left/right, y: height, z: depth)
                let positions: [SIMD3<Float>] = [
                    SIMD3<Float>(-0.4, 1.2, -1.5),
                    SIMD3<Float>( 0.3, 1.6, -1.8),
                    SIMD3<Float>(-0.1, 1.0, -1.3),
                    SIMD3<Float>( 0.5, 1.4, -2.0),
                    SIMD3<Float>(-0.6, 1.7, -1.6),
                ]

                for position in positions {
                    let clone = glassSphere.clone(recursive: true)
                    clone.position = position
                    scene.addChild(clone)
                }
            }
        }
        .gesture(tapExample)
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

    var tapExample: some Gesture {
        TapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let pointLight = self.pointLight {
                    pointLight.position = value.entity.position
                }
            }
    }

}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
