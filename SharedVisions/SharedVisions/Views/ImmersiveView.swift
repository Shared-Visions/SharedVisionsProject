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

                let positions = Self.generateSpherePositions(count: appModel.sphereCount)
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

    /// Generates positions for glass spheres distributed in a frustum region
    /// around and beyond a video player that sits ~2m in front of the user.
    ///
    /// The user is at the origin facing -Z. A narrow inner cone (the video player zone)
    /// is excluded. Spheres are placed in the wider surrounding cone from ~2m out to ~8m.
    static func generateSpherePositions(count: Int) -> [SIMD3<Float>] {
        // Seeded RNG so positions are stable across launches
        var rng = SplitMix64(seed: 42)

        let minDepth: Float = 1.5   // some spheres can be close, just not in the exclusion zone
        let maxDepth: Float = 8.0
        let videoPlayerDepth: Float = 2.0 // where the video player sits
        let innerHalfAngle: Float = 15 * (.pi / 180) // narrow cone to exclude (user -> video player)
        let outerHalfAngle: Float = 60 * (.pi / 180) // wide placement cone
        let minY: Float = 0.3
        let maxY: Float = 3.5

        var positions: [SIMD3<Float>] = []

        while positions.count < count {
            // Random depth (square root bias for uniform area distribution)
            let t = Float.random(in: 0...1, using: &rng)
            let depth = minDepth + (maxDepth - minDepth) * sqrtf(t)

            // Width of the outer cone at this depth
            let outerWidth = depth * tan(outerHalfAngle)

            // Random X position within the outer cone
            let x = Float.random(in: -outerWidth...outerWidth, using: &rng)

            // Only exclude the narrow inner cone in FRONT of the video player (depth < 2m).
            // Beyond the video player, the full width is fair game.
            if depth < videoPlayerDepth {
                let innerWidth = depth * tan(innerHalfAngle)
                if abs(x) < innerWidth {
                    continue
                }
            }

            // Random Y with some variation
            let y = Float.random(in: minY...maxY, using: &rng)

            // Depth is negative Z (in front of user)
            positions.append(SIMD3<Float>(x, y, -depth))
        }

        return positions
    }

    var tapExample: some Gesture {
        TapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let pointLight = self.pointLight {
                    let targetPosition = value.entity.position
                    Self.animateLightMove(pointLight, to: targetPosition)
                }
            }
    }

    /// Animates the point light from its current position to the target with a bounce at the end.
    /// Uses two sequenced FromToByAction animations: a fast move that overshoots, then a settle-back.
    static func animateLightMove(_ light: Entity, to target: SIMD3<Float>) {
        light.stopAllAnimations()

        let currentTransform = light.transform
        let direction = target - currentTransform.translation
        let distance = length(direction)

        // Overshoot by a small amount of the travel distance along the movement direction
        let overshootFraction: Float = 0.05
        let overshootPosition = target + normalize(direction) * (distance * overshootFraction)

        let overshootTransform = Transform(
            scale: currentTransform.scale,
            rotation: currentTransform.rotation,
            translation: overshootPosition
        )
        let finalTransform = Transform(
            scale: currentTransform.scale,
            rotation: currentTransform.rotation,
            translation: target
        )

        // Phase 1: Quick move from current position to overshoot point
        let moveAction = FromToByAction<Transform>(
            from: currentTransform,
            to: overshootTransform,
            timing: .easeIn,
            isAdditive: false
        )
        let moveDuration: TimeInterval = 0.25

        // Phase 2: Settle back from overshoot to final position
        let settleAction = FromToByAction<Transform>(
            from: overshootTransform,
            to: finalTransform,
            timing: .easeOut,
            isAdditive: false
        )
        let settleDuration: TimeInterval = 0.15

        guard let moveAnimation = try? AnimationResource.makeActionAnimation(
            for: moveAction,
            duration: moveDuration,
            bindTarget: .transform
        ),
        let settleAnimation = try? AnimationResource.makeActionAnimation(
            for: settleAction,
            duration: settleDuration,
            bindTarget: .transform
        ) else { return }

        let sequence = try? AnimationResource.sequence(with: [moveAnimation, settleAnimation])
        guard let sequence else { return }

        light.playAnimation(sequence)
    }

}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
/// A simple deterministic random number generator (SplitMix64).
/// Produces the same sequence of values for a given seed.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

