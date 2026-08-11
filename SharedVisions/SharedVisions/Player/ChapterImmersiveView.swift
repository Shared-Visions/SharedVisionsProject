//

//  ImmersiveView.swift
//  SharedVisions
//
//  Thin shell around RealityView. The `make` closure builds the empty
//  scene root + the skybox sphere (the binding target for segment video
//  backdrops) and registers them with the executors. Everything else
//  — primitive entities, video panels, lights, USDZ props — comes
//  from the Maestro-authored `.chapterscript` document via
//  `DocumentEntityLoader`. The `update` closure drives per-frame
//  motion for any `.animateMotion` actions the loaded segments
//  declare.
//

import SwiftUI
import RealityKit
import AVFoundation
import OSLog
import ChapterPlayer

private let immersiveLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.shellcorp.sharedvisions",
    category: "ImmersiveView"
)

struct ChapterImmersiveView: View {
    @Environment(PlayerModel.self) private var appModel

    @State private var skyboxEntity: Entity?
    @State private var sceneRoot: Entity?

    /// Per-frame animation driver. RealityView's `update:` closure only
    /// runs on view re-renders — during steady playback nothing observable
    /// changes per frame (step state changes only at step boundaries), so
    /// motion sampling there effectively froze between steps. A
    /// SceneEvents.Update subscription fires every render frame.
    @State private var motionDriver: EventSubscription?

    var body: some View {
        RealityView { content in
            await appModel.assetPreloader.preloadAll()

            let root = Entity()
            root.name = "ImmersiveRoot"
            content.add(root)
            sceneRoot = root
            appModel.effectExecutor.sceneRoot = root
            // Hand the root to AppModel so DocumentEntityLoader can
            // materialize loaded-document entities under it. The didSet
            // hook replays materialization if a document is already
            // loaded before the immersive space opens.
            appModel.immersiveSceneRoot = root

            // Skybox shell — empty anchor that `VideoPlaybackManager`
            // binds a configured `VideoPlayerComponent` onto when a
            // segment's `playVideo` action uses `.immersive`
            // presentation, or when a segment's `immersiveBackdrop`
            // is `.video`. Disabled by default;
            // `AppModel.applyAmbientBackgroundVisibility` flips it
            // on when a segment declares a video backdrop.
            let skybox = createSkyboxShell()
            skyboxEntity = skybox
            root.addChild(skybox)
            appModel.videoManager.videoEntityRegistry["skybox"] = skybox
            immersiveLogger.info("[setup] skybox entity registered. registry keys: \(appModel.videoManager.videoEntityRegistry.keys.sorted())")

            // Drive per-frame motion from the render loop — the update:
            // closure only fires when SwiftUI re-renders (once per step
            // during steady playback), which froze segment-track and
            // animateMotion curves between steps.
            motionDriver = content.subscribe(to: SceneEvents.Update.self) { _ in
                drivePerFrameMotion()
            }
        }
        .onDisappear {
            appModel.sequenceEngine.stop(resetEntities: true, fullReset: false)
            appModel.audioManager.stopAll()
            appModel.videoManager.stopAll()
        }
    }

    // MARK: - Skybox

    /// Empty anchor for immersive video playback. RealityKit's
    /// `VideoPlayerComponent` handles ALL the spherical projection
    /// internally when `desiredImmersiveViewingMode` is set — no
    /// sphere mesh, no `VideoMaterial`, no manual geometry. Apple's
    /// own `PlayingImmersiveMediaWithRealityKit` sample uses exactly
    /// this pattern: an empty `Entity()` + a configured
    /// `VideoPlayerComponent`.
    ///
    /// Earlier revisions of this view shipped a 1000m sphere with a
    /// `VideoMaterial` bound to a placeholder AVPlayer. That worked
    /// for non-stereo mono videos but broke spatial / MV-HEVC / AIVU
    /// content — the material rendered one eye's pixels stretched
    /// across the sphere and ignored stereo metadata entirely.
    ///
    /// The entity is hidden until a video binds — see
    /// `AppModel.applyAmbientBackgroundVisibility`.
    @MainActor
    private func createSkyboxShell() -> Entity {
        let entity = Entity()
        entity.name = "skybox"
        entity.isEnabled = false
        return entity
    }

    // MARK: - Per-frame continuous motion

    /// Per-frame motion is fully data-driven: any `.animateMotion` action that ran at
    /// step start populated `entityExecutor.activeMotions`; here we ask the executor
    /// to evaluate each curve against the engine's current step / total elapsed time
    /// and write the resulting transforms onto live entities.
    ///
    /// The previous step-id switch with hand-tuned trigonometry is gone. Curves are
    /// authored declaratively in the experience JSON via `MotionCurve` sum-types.
    @MainActor
    private func drivePerFrameMotion() {
        let engine = appModel.sequenceEngine
        appModel.entityExecutor.applyActiveMotions(
            stepElapsed: engine.stepElapsed,
            totalElapsed: engine.totalElapsed
        )
    }
}
