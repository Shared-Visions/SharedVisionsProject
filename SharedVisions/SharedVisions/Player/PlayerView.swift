//

//  PlaybackView.swift
//  SharedVisions
//
//  Segmented timeline scrub bar. Each segment is a major block; each step is
//  a clickable sub-block. Click snaps to that step (jumping segments if
//  needed). A playhead indicator tracks the engine's current position.
//

import SwiftUI
import UniformTypeIdentifiers
import ChapterPlayer

struct PlayerView: View {
    @Environment(PlayerModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var showingFileImporter = false

    // Visual tuning
    private let barHeight: CGFloat = 56
    private let segmentGap: CGFloat = 4      // gap between adjacent segment blocks
    private let stepGap: CGFloat = 1         // gap between adjacent steps within a segment

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                timelineBar
                    .frame(height: barHeight)
                currentStepDetails
                transportControls
                Spacer(minLength: 0)
            }
            .padding(16)

            // Phase 5.5: full-cover loading state replaces the previous
            // "frozen timeline" feel during a live connect. Animates in
            // when isLoadingLiveExperience flips and out when the segment
            // starts playing.
            if appModel.isLoadingLiveExperience {
                LiveLoadingOverlay(prefetchProgress: appModel.livePrefetchProgress)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.isLoadingLiveExperience)
        .task {
            // Kaiser pattern: hand the core the space actions from a view
            // that has them — transitionToPhase("immersive"/"idle") is a
            // no-op until these land.
            if appModel.openSpace == nil {
                appModel.openSpace = { id in await openImmersiveSpace(id: id) }
            }
            if appModel.dismissSpace == nil {
                appModel.dismissSpace = { await dismissImmersiveSpace() }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType("com.maestrovision.chapterscript") ?? .directory, .directory],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    await appModel.transitionToPhase("immersive")
                    await appModel.loadAndPlayLocalExperience(at: url)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SHARED VISIONS")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(.secondary)
            Text(appModel.sequenceEngine.currentSequence?.name ?? "Ready to play")
                .font(.title3)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Timeline bar

    @ViewBuilder
    private var timelineBar: some View {
        GeometryReader { geo in
            // When a ChapterScript chapter document is loaded (bundled or
            // live), use its segments so the timeline reflects what's
            // actually playing.
            let segments = appModel.displaySequences
            let totalDuration = max(segments.reduce(0) { $0 + $1.totalDuration }, 0.001)
            let _ = totalDuration

            if segments.isEmpty {
                // Empty state — shown briefly between live loads while
                // the document is being fetched. Keeps the bar from
                // flashing the documentary's stale segments.
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        Text("Waiting for chapter…")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    )
            } else {
            let totalSegmentGaps = CGFloat(max(segments.count - 1, 0)) * segmentGap
            let usableWidth = max(geo.size.width - totalSegmentGaps, 0.001)

            ZStack(alignment: .leading) {
                HStack(spacing: segmentGap) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        let segmentWidth = usableWidth * CGFloat(segment.totalDuration / totalDuration)
                        segmentBlock(segment: segment, index: index, width: segmentWidth)
                    }
                }
                // Keep the tick signal inside the subtree that actually needs it.
                // Placing TimelineView here (rather than around the whole timelineBar)
                // ensures the playhead offset is re-computed every tick even if
                // outer @Observable state hasn't changed — `engine.stepElapsed`
                // depends on Date.now, which is not observable on its own.
                TimelineView(.periodic(from: .now, by: 0.05)) { context in
                    // Reading context.date keeps SwiftUI honest about this closure's
                    // dependency on time, even though we use engine.stepElapsed below.
                    let _ = context.date
                    playheadOverlay(
                        segments: segments,
                        totalDuration: totalDuration,
                        usableWidth: usableWidth
                    )
                }
                .allowsHitTesting(false)
            }
            } // else
        }
    }

    @ViewBuilder
    private func segmentBlock(segment: SequenceDefinition, index: Int, width: CGFloat) -> some View {
        let engine = appModel.sequenceEngine
        let isActiveSegment = engine.currentSequence?.id == segment.id
        let stepCount = segment.steps.count
        let totalStepGaps = CGFloat(max(stepCount - 1, 0)) * stepGap
        let stepArea = max(width - totalStepGaps, 0.001)

        VStack(spacing: 4) {
            HStack(spacing: stepGap) {
                ForEach(Array(segment.steps.enumerated()), id: \.element.id) { stepIdx, step in
                    let stepWidth = stepArea * CGFloat(step.duration / segment.totalDuration)
                    stepCell(
                        segment: segment,
                        stepIdx: stepIdx,
                        step: step,
                        isActiveSegment: isActiveSegment,
                        isActiveStep: isActiveSegment && engine.currentStepIndex == stepIdx,
                        width: stepWidth
                    )
                }
            }
            .frame(height: 32)
            segmentLabel(segment: segment, index: index, isActive: isActiveSegment, width: width)
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isActiveSegment {
                jump(to: segment, stepIndex: 0)
            }
        }
    }

    @ViewBuilder
    private func stepCell(
        segment: SequenceDefinition,
        stepIdx: Int,
        step: StepDefinition,
        isActiveSegment: Bool,
        isActiveStep: Bool,
        width: CGFloat
    ) -> some View {
        let engine = appModel.sequenceEngine
        let isPast = isActiveSegment && stepIdx < engine.currentStepIndex
        let fill = stepFill(isActiveStep: isActiveStep, isPast: isPast, isActiveSegment: isActiveSegment)

        Button {
            jump(to: segment, stepIndex: stepIdx)
        } label: {
            Rectangle()
                .fill(fill)
                .frame(width: max(width, 3))
                .overlay(
                    Rectangle()
                        .stroke(isActiveStep ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .help("\(segment.name) — \(step.name) (\(Int(step.duration))s)")
    }

    private func stepFill(isActiveStep: Bool, isPast: Bool, isActiveSegment: Bool) -> Color {
        if isActiveStep { return Color.accentColor }
        if isPast { return Color.accentColor.opacity(0.4) }
        if isActiveSegment { return Color.secondary.opacity(0.35) }
        return Color.secondary.opacity(0.18)
    }

    @ViewBuilder
    private func segmentLabel(segment: SequenceDefinition, index: Int, isActive: Bool, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 14, alignment: .trailing)
            Text(segment.name)
                .font(.caption2)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func playheadOverlay(
        segments: [SequenceDefinition],
        totalDuration: TimeInterval,
        usableWidth: CGFloat
    ) -> some View {
        let engine = appModel.sequenceEngine
        if let currentSequence = engine.currentSequence {
            let x = computePlayheadX(
                segments: segments,
                currentSequenceId: currentSequence.id,
                currentStepIndex: engine.currentStepIndex,
                stepElapsed: engine.stepElapsed,
                totalDuration: totalDuration,
                usableWidth: usableWidth
            )
            // Pin to leading edge; offset shifts it rightward. maxWidth: .infinity
            // ensures the container spans the full ZStack so offset measures from
            // the leading (x=0) edge consistently.
            ZStack(alignment: .topLeading) {
                Color.clear
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 40)
                    .shadow(color: .white.opacity(0.9), radius: 3)
                    .offset(x: max(0, x - 1), y: 0)
            }
        }
    }

    /// Walks the exact layout used by `segmentBlock` to determine the pixel position
    /// of the current playback point. This matches the rendered segment boundaries
    /// (segment gaps and step gaps included) rather than approximating against
    /// `usableWidth` directly.
    private func computePlayheadX(
        segments: [SequenceDefinition],
        currentSequenceId: String,
        currentStepIndex: Int,
        stepElapsed: TimeInterval,
        totalDuration: TimeInterval,
        usableWidth: CGFloat
    ) -> CGFloat {
        var x: CGFloat = 0
        for (idx, segment) in segments.enumerated() {
            if idx > 0 { x += segmentGap }
            let segmentWidth = usableWidth * CGFloat(segment.totalDuration / totalDuration)

            if segment.id == currentSequenceId {
                // Walk steps within this segment
                let stepCount = segment.steps.count
                let totalStepGaps = CGFloat(max(stepCount - 1, 0)) * stepGap
                let stepArea = max(segmentWidth - totalStepGaps, 0.001)
                for (sIdx, step) in segment.steps.enumerated() {
                    if sIdx > 0 { x += stepGap }
                    let stepWidth = max(3, stepArea * CGFloat(step.duration / segment.totalDuration))
                    if sIdx == currentStepIndex {
                        let progress = min(1.0, max(0.0, stepElapsed / max(step.duration, 0.001)))
                        x += stepWidth * CGFloat(progress)
                        return x
                    }
                    x += stepWidth
                }
                return x
            } else {
                x += segmentWidth
            }
        }
        return x
    }

    // MARK: - Current step details

    @ViewBuilder
    private var currentStepDetails: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let _ = context.date
            let engine = appModel.sequenceEngine
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    if let segment = engine.currentSequence, let step = engine.currentStep {
                        Text("Step \(engine.currentStepIndex + 1) / \(segment.steps.count)  ·  \(step.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(formatted(engine.stepElapsed)) / \(formatted(step.duration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No step").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusBadge(engine: engine)
            }
        }
    }

    @ViewBuilder
    private func statusBadge(engine: SequenceEngine) -> some View {
        let (label, color) = statusLabelAndColor(engine: engine)
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption)
        }
    }

    private func statusLabelAndColor(engine: SequenceEngine) -> (String, Color) {
        if !engine.isPlaying { return ("Stopped", .secondary) }
        if engine.isPaused   { return ("Paused",  .yellow) }
        if engine.isWaiting  { return ("Waiting", .orange) }
        return ("Playing", .green)
    }

    // MARK: - Transport

    @ViewBuilder
    private var transportControls: some View {
        let engine = appModel.sequenceEngine
        let isImmersive = appModel.immersiveSpaceState == .open
        let isPlayingForward = engine.isPlaying && !engine.isPaused

        HStack(spacing: 14) {
            Button { engine.previous() } label: {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(TransportButtonStyle(variant: .secondary, size: 46))

            Button { engine.togglePause() } label: {
                Image(systemName: isPlayingForward ? "pause.fill" : "play.fill")
                    // Nudge the play triangle right a hair so it reads centered.
                    .offset(x: isPlayingForward ? 0 : 2)
            }
            .buttonStyle(TransportButtonStyle(variant: .primary, size: 64))

            Button { engine.skip() } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(TransportButtonStyle(variant: .secondary, size: 46))

            Button { engine.restart() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(TransportButtonStyle(variant: .secondary, size: 46))

            // Discover + connect to MaestroStudio on the LAN. Primary
            // way to load an experience — the app no longer ships
            // bundled demos.
            LiveModeView()

            Button {
                showingFileImporter = true
            } label: {
                Image(systemName: "folder.fill")
            }
            .buttonStyle(TransportButtonStyle(variant: .secondary, size: 46))
            .help("Open a .chapterscript project from Files")

            Spacer()

            Button {
                if isImmersive {
                    Task { await appModel.transitionToPhase("idle") }
                } else {
                    Task {
                        await appModel.transitionToPhase("immersive")
                        // No bundled fallback — if no experience is
                        // loaded, the immersive space opens empty and
                        // the author is expected to use the Live menu
                        // (LAN connect to Maestro) or the main window's
                        // "Open Project" button.
                    }
                }
            } label: {
                Image(systemName: isImmersive ? "stop.fill" : "play.circle.fill")
            }
            .buttonStyle(TransportButtonStyle(
                variant: isImmersive ? .destructive : .launch,
                size: 54
            ))
        }
    }

    // MARK: - Helpers

    private func jump(to segment: SequenceDefinition, stepIndex: Int) {
        let engine = appModel.sequenceEngine
        if appModel.immersiveSpaceState == .closed {
            Task {
                await appModel.transitionToPhase("immersive")
                if appModel.immersiveSpaceState == .open {
                    engine.play(sequence: segment, startingAtStepIndex: stepIndex)
                }
            }
            return
        }
        if engine.currentSequence?.id == segment.id {
            engine.jumpToStep(index: stepIndex)
        } else {
            engine.play(sequence: segment, startingAtStepIndex: stepIndex)
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN, !seconds.isInfinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Transport Button Style

private struct TransportButtonStyle: ButtonStyle {

    enum Variant {
        case primary      // play/pause — big, accent-colored, glowing
        case secondary    // prev/skip/restart — subtler glass
        case launch       // green "start experience"
        case destructive  // red "stop experience"
    }

    let variant: Variant
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let iconSize = size * 0.38

        configuration.label
            .font(.system(size: iconSize, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background {
                ZStack {
                    // Base fill — deep, dimensional
                    Circle()
                        .fill(backgroundGradient)

                    // Inner highlight — catches "light" from the top
                    Circle()
                        .fill(LinearGradient(
                            colors: [
                                Color.white.opacity(variant == .secondary ? 0.18 : 0.35),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        ))
                        .blendMode(.plusLighter)

                    // Rim stroke — crisp edge
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                }
            }
            .shadow(color: glowColor.opacity(pressed ? 0.2 : 0.55),
                    radius: pressed ? 4 : 14,
                    y: pressed ? 1 : 4)
            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
            .scaleEffect(pressed ? 0.92 : 1.0)
            .brightness(pressed ? -0.05 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: pressed)
            .contentShape(Circle())
            .hoverEffect(.lift)
    }

    // MARK: - Color tables

    private var backgroundGradient: LinearGradient {
        switch variant {
        case .primary:
            return LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.62, blue: 1.0),
                    Color(red: 0.14, green: 0.32, blue: 0.78)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .secondary:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.06)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .launch:
            return LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.92, blue: 0.55),
                    Color(red: 0.10, green: 0.55, blue: 0.28)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .destructive:
            return LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.40, blue: 0.38),
                    Color(red: 0.68, green: 0.10, blue: 0.12)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var iconColor: Color {
        switch variant {
        case .primary, .launch, .destructive: return .white
        case .secondary:                      return .white.opacity(0.95)
        }
    }

    private var glowColor: Color {
        switch variant {
        case .primary:     return Color(red: 0.35, green: 0.62, blue: 1.0)
        case .secondary:   return .white
        case .launch:      return Color(red: 0.35, green: 0.92, blue: 0.55)
        case .destructive: return Color(red: 1.00, green: 0.40, blue: 0.38)
        }
    }
}
