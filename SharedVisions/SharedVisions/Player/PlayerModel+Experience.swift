//

//  AppModel+Experience.swift
//  SharedVisions
//
//  Loads a ChapterScript experience document via an `ExperienceProvider`,
//  converts the chosen segment into a runtime `SequenceDefinition`, and plays it.
//
//  Phase 1 entry point — exercises the full DTO → runtime mapping path
//  with the `ColorDrift.chapterscript` bundle shipped alongside the app.
//

import Foundation
import OSLog
import ChapterScript
import ChapterPlayer

private let experienceLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.shellcorp.sharedvisions",
    category: "Experience"
)

extension PlayerModel {

    /// Load a `.chapterscript` directory bundle from disk and play its
    /// default segment. Used by the main-window file-importer flow when
    /// the author opens a project saved by Maestro.
    func loadAndPlayLocalExperience(at url: URL, segmentId: String? = nil) async {
        let provider = LocalFolderExperienceProvider(folderURL: url)
        do {
            let loaded = try await provider.load()
            let resolvedId = segmentId
                ?? loaded.document.defaultSequenceId
                ?? loaded.document.sequences.first?.id
            guard let id = resolvedId else {
                experienceLogger.error("Loaded experience '\(loaded.document.id)' has no segments.")
                return
            }
            guard let dto = loaded.document.sequences.first(where: { $0.id == id }) else { return }
            let segment = try SequenceDefinition(dto: dto)
            experienceLogger.info(
                "Loaded experience '\(loaded.document.id)' from '\(url.lastPathComponent)' (\(loaded.document.sequences.count) segments); starting at '\(segment.id)' (\(segment.steps.count) steps, \(segment.totalDuration)s)"
            )
            loadedExperience = loaded
            audioManager.mediaResolver = loaded.mediaResolver
            videoManager.mediaResolver = loaded.mediaResolver
            documentEntities.materialize(document: loaded.document, sceneRoot: immersiveSceneRoot, mediaResolver: loaded.mediaResolver)
            await playSequence(segment)
        } catch {
            experienceLogger.error("Failed to load experience at '\(url.lastPathComponent)': \(String(describing: error))")
        }
    }

    /// Phase 5: load a live experience from a discovered MaestroStudio
    /// instance over Bonjour + HTTP, then subscribe to /events for hot-reload.
    /// Each `doc-changed` event re-fetches the document and replays the
    /// current segment (or the document's defaultSequenceId if none).
    ///
    /// Sets `isLoadingLiveExperience` for the duration of the network fetch
    /// so the immersive space's mount-time documentary auto-play knows to
    /// stand down (otherwise the bundled JSON would race-win and replace
    /// the live document moments after we set it).
    func playLiveExperience(from descriptor: LiveServerDescriptor) async {
        isLoadingLiveExperience = true
        defer { isLoadingLiveExperience = false }

        // Hard reset on the way into the live load:
        //   • Stop the segment engine so the previous segment isn't still
        //     ticking under the loading overlay.
        //   • Stop any in-flight audio / video so the user gets actual
        //     silence + a clean visual state during connect.
        //   • Clear `loadedExperience` so the timeline scrub bar can
        //     render an empty state instead of the documentary's eight
        //     hardcoded segments while the live document arrives.
        sequenceEngine.stop(resetEntities: true, fullReset: true)
        audioManager.stopAll()
        videoManager.stopAll()
        loadedExperience = nil
        documentEntities.unload()
        liveLoadingDescriptor = descriptor

        let provider = LiveDevExperienceProvider(descriptor: descriptor, prefetchProgress: livePrefetchProgress)
        do {
            let loaded = try await provider.load()
            let id = loaded.document.defaultSequenceId ?? loaded.document.sequences.first?.id
            guard let segmentId = id else {
                experienceLogger.error("Live document has no segments: \(loaded.document.id)")
                liveLoadError = "Live document has no segments."
                return
            }
            let segment = try SequenceDefinition(dto: loaded.document.sequences.first(where: { $0.id == segmentId })!)
            experienceLogger.info(
                "Loaded live experience '\(loaded.document.id)' from \(descriptor.serviceName) — \(loaded.document.sequences.count) segment(s), starting at '\(segment.id)'"
            )
            loadedExperience = loaded
            audioManager.mediaResolver = loaded.mediaResolver
            videoManager.mediaResolver = loaded.mediaResolver
            documentEntities.materialize(document: loaded.document, sceneRoot: immersiveSceneRoot, mediaResolver: loaded.mediaResolver)
            // Phase 5.5: warm every video referenced by the document so
            // the first `playVideo` action doesn't sit waiting for HTTP
            // chunks. This makes the start of every segment beat-perfect.
            // Also explicitly preheats the segment-to-play's immersive
            // backdrop video so the skybox doesn't cold-bind on first
            // entry (the bug behind "skybox sometimes doesn't load until
            // I reopen the connection").
            await preheatVideosFor(
                document: loaded.document,
                mediaResolver: loaded.mediaResolver,
                firstSegment: segment
            )
            liveLoadError = nil
            liveLoadingDescriptor = nil
            await playSequence(segment)
            startLiveSubscription(descriptor: descriptor)
        } catch {
            experienceLogger.error("Live load failed: \(String(describing: error))")
            liveLoadError = "Couldn't reach \(descriptor.serviceName): \(error.localizedDescription)"
        }
    }

    /// Warm AVPlayer items for every video file referenced anywhere in the
    /// document, so the first `playVideo` action doesn't stall waiting for
    /// HTTP chunks or texture binding. Each channel runs the full
    /// `prepareAsync` flow (track load → preroll → bind VideoMaterial →
    /// force first-frame production → pause). Channels are warmed in
    /// parallel so a document with five videos doesn't take 5× as long.
    ///
    /// When the segment eventually fires its `playVideo`, the play() fast
    /// path picks up the prepared channel and only has to flip
    /// `entity.isEnabled = true` + `player.play()` — first frame appears
    /// the same render tick.
    private func preheatVideosFor(
        document: ChapterDocument,
        mediaResolver: MediaResolver,
        firstSegment: SequenceDefinition? = nil
    ) async {
        var seen = Set<String>()
        var actions: [VideoAction] = []
        for segment in document.sequences {
            for step in segment.steps {
                for action in step.actions + step.scheduledActions.map(\.action) {
                    if case .playVideo(let dto) = action, !seen.contains(dto.channel) {
                        seen.insert(dto.channel)
                        actions.append(VideoAction(dto))
                    }
                }
            }
        }
        // Also warm the about-to-play segment's immersive backdrop video
        // on the dedicated backdrop channel — otherwise the first segment
        // binds it cold from `applySegmentBackdrop` and the
        // VideoPlayerComponent attach can lose the readyToPlay race on
        // first connect (the "skybox doesn't show until reopen" bug).
        if let segment = firstSegment,
           case .video(let file, let layout, let field, let radius, let loop, _) = segment.immersiveBackdrop,
           !seen.contains(PlayerModel.backdropVideoChannel) {
            seen.insert(PlayerModel.backdropVideoChannel)
            actions.append(VideoAction(
                file: file,
                channel: PlayerModel.backdropVideoChannel,
                volume: 0,
                loop: loop,
                presentation: .immersive(radius: radius, field: field),
                layout: layout
            ))
        }
        guard !actions.isEmpty else { return }

        // Run all preheats in parallel — visionOS handles multiple
        // AVPlayer prerolls fine, and the LiveServer is happy serving
        // concurrent Range requests.
        await withTaskGroup(of: Void.self) { group in
            for action in actions {
                group.addTask { @MainActor [weak self] in
                    await self?.videoManager.prepareAsync(action: action)
                }
            }
            await group.waitForAll()
        }
        experienceLogger.info("Warmed \(actions.count) video channel(s) before segment start")
    }

    /// Re-fetch the current live document and resume playback at the same
    /// segment id. Triggered by SSE doc-changed events.
    func reloadLiveExperience() async {
        guard let descriptor = liveSubscriptionDescriptor else { return }
        let provider = LiveDevExperienceProvider(descriptor: descriptor, prefetchProgress: livePrefetchProgress)
        do {
            let loaded = try await provider.load()
            // Keep the currently-active segment id if it still exists in the
            // refreshed document; otherwise drop back to the document's
            // defaultSequenceId.
            let activeId = activeSequenceId
            let segmentId: String? = {
                if let id = activeId, loaded.document.sequences.contains(where: { $0.id == id }) {
                    return id
                }
                return loaded.document.defaultSequenceId ?? loaded.document.sequences.first?.id
            }()
            guard let id = segmentId else { return }
            guard let dto = loaded.document.sequences.first(where: { $0.id == id }) else { return }
            let segment = try SequenceDefinition(dto: dto)
            loadedExperience = loaded
            audioManager.mediaResolver = loaded.mediaResolver
            videoManager.mediaResolver = loaded.mediaResolver
            documentEntities.materialize(document: loaded.document, sceneRoot: immersiveSceneRoot, mediaResolver: loaded.mediaResolver)
            experienceLogger.info("Hot-reloaded segment '\(segment.id)' from live")
            await playSequence(segment)
        } catch {
            experienceLogger.error("Live reload failed: \(String(describing: error))")
        }
    }

    /// Stop hot-reload subscription. Existing segment continues playing.
    func stopLiveSubscription() {
        liveSubscription?.cancel()
        liveSubscription = nil
        liveSubscriptionDescriptor = nil
    }

    private func startLiveSubscription(descriptor: LiveServerDescriptor) {
        stopLiveSubscription()
        liveSubscriptionDescriptor = descriptor
        liveSubscription = LiveSubscription(descriptor: descriptor) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.reloadLiveExperience()
            }
        }
    }
}

extension PlayerModel {

    /// Play (or REPLAY) the loaded document's default sequence — the
    /// transport's launch/play path. After a sequence completes the
    /// engine is stopped with no active sequence, so "press play again"
    /// must resolve a sequence from the document rather than poking the
    /// stopped engine. Opens the immersive space first when needed.
    func playDefaultSequence() async {
        guard let document = loadedExperience?.document else { return }
        let id = document.defaultSequenceId ?? document.sequences.first?.id
        guard let id, let sequence = sequenceFromLoadedDocument(id: id) else { return }
        if immersiveSpaceState == .closed {
            await transitionToPhase("immersive")
        }
        guard immersiveSpaceState == .open else { return }
        await playSequence(sequence)
    }
}
