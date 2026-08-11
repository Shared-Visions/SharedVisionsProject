//
//  PlayerControlBar.swift
//  SharedVisions
//
//  System-video-player-style control bar, shown ONLY inside the
//  immersive space (mounted as a RealityView attachment by
//  ChapterImmersiveView). Layout mirrors the visionOS media player:
//  elapsed/total + title, a scrub bar with step-boundary dots, then
//  transport on the left and volume / captions / settings on the right.
//

import SwiftUI
import ChapterScript
import ChapterPlayer

struct PlayerControlBar: View {
    @Environment(PlayerModel.self) private var appModel

    /// Live drag fraction while scrubbing; nil when idle.
    @State private var scrubFraction: Double?

    var body: some View {
        // Engine time advances without any @Observable change per frame —
        // poll at 4 Hz so the readout and bar track playback.
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            content
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(width: 640)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        let engine = appModel.sequenceEngine
        let sequence = displaySequence
        let total = sequence?.totalDuration ?? 0
        let elapsed = engine.isPlaying || engine.isPaused ? min(engine.totalElapsed, total) : 0

        // Held at the end (onComplete = holdOnLastStep keeps the engine
        // "playing" parked on the last frame) — play must RESTART, not
        // toggle pause on a finished run.
        let atEnd = engine.isPlaying && total > 0 && engine.totalElapsed >= total - 0.05

        VStack(alignment: .leading, spacing: 14) {
            // ── Time + title
            HStack(spacing: 10) {
                (Text(formatted(scrubFraction.map { $0 * total } ?? elapsed))
                    .foregroundStyle(.white)
                 + Text(" / \(formatted(total))")
                    .foregroundStyle(.secondary))
                    .font(.callout.weight(.semibold).monospacedDigit())
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            // ── Scrub bar with step-boundary dots
            scrubBar(sequence: sequence, total: total, elapsed: elapsed)

            // ── Transport + utilities
            HStack(spacing: 30) {
                Button {
                    // System-player semantics: mid-step (or at the first
                    // step) restarts the CURRENT step; near a step start
                    // goes to the previous one. Works from the held-at-end
                    // state too — jumpToStep rebuilds the play task.
                    if engine.currentStepIndex == 0 || engine.stepElapsed > 2 || atEnd {
                        engine.jumpToStep(index: atEnd ? 0 : engine.currentStepIndex)
                    } else {
                        engine.previous()
                    }
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                Button {
                    if atEnd {
                        engine.restart()
                    } else if engine.isPlaying {
                        engine.togglePause()
                    } else {
                        Task { await appModel.playDefaultSequence() }
                    }
                } label: {
                    Image(systemName: engine.isPlaying && !engine.isPaused && !atEnd ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 30)
                }
                Button { engine.skip() } label: {
                    Image(systemName: "forward.end.fill")
                }

                Spacer()

                Button { appModel.toggleMuted() } label: {
                    Image(systemName: appModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                // Captions: no subtitle system yet — presented for layout
                // parity with the system player, disabled until wired.
                Button {} label: {
                    Image(systemName: "captions.bubble")
                }
                .disabled(true)

                Menu {
                    if appModel.displaySequences.count > 1 {
                        Section("Sequences") {
                            ForEach(appModel.displaySequences, id: \.id) { seq in
                                Button(seq.name.isEmpty ? seq.id : seq.name) {
                                    engine.play(sequence: seq)
                                }
                            }
                        }
                    }
                    Button(role: .destructive) {
                        Task { await appModel.transitionToPhase("idle") }
                    } label: {
                        Label("Exit Player", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
            .font(.system(size: 19, weight: .semibold))
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
        }
    }

    // MARK: - Scrub bar

    @ViewBuilder
    private func scrubBar(sequence: SequenceDefinition?, total: TimeInterval, elapsed: TimeInterval) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = scrubFraction ?? (total > 0 ? elapsed / total : 0)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                    .frame(height: 5)
                Capsule().fill(.white)
                    .frame(width: max(5, width * fraction), height: 5)
                // Step-boundary dots — the system player's chapter marks.
                ForEach(stepFractions(sequence: sequence, total: total), id: \.self) { f in
                    Circle()
                        .fill(.white.opacity(f <= fraction ? 1 : 0.55))
                        .frame(width: 7, height: 7)
                        .position(x: width * f, y: geo.size.height / 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        scrubFraction = min(max(value.location.x / width, 0), 1)
                    }
                    .onEnded { value in
                        let f = min(max(value.location.x / width, 0), 1)
                        scrubFraction = nil
                        seek(toFraction: f, sequence: sequence, total: total)
                    }
            )
        }
        .frame(height: 20)
    }

    /// Snap a released scrub to the step containing that time.
    private func seek(toFraction f: Double, sequence: SequenceDefinition?, total: TimeInterval) {
        guard let sequence, total > 0 else { return }
        let target = f * total
        var cursor: TimeInterval = 0
        for (index, step) in sequence.steps.enumerated() {
            if target < cursor + step.duration || index == sequence.steps.count - 1 {
                let engine = appModel.sequenceEngine
                if engine.currentSequence?.id == sequence.id, engine.isPlaying {
                    engine.jumpToStep(index: index)
                } else {
                    engine.play(sequence: sequence, startingAtStepIndex: index)
                }
                return
            }
            cursor += step.duration
        }
    }

    private func stepFractions(sequence: SequenceDefinition?, total: TimeInterval) -> [Double] {
        guard let sequence, total > 0, sequence.steps.count > 1 else { return [] }
        var fractions: [Double] = []
        var cursor: TimeInterval = 0
        for step in sequence.steps.dropLast() {
            cursor += step.duration
            fractions.append(cursor / total)
        }
        return fractions
    }

    // MARK: - Derived

    private var displaySequence: SequenceDefinition? {
        appModel.sequenceEngine.currentSequence
            ?? appModel.displaySequences.first {
                $0.id == appModel.loadedExperience?.document.defaultSequenceId
            }
            ?? appModel.displaySequences.first
    }

    private var title: String {
        if let sequence = displaySequence, !sequence.name.isEmpty { return sequence.name }
        return appModel.loadedExperience?.document.displayName
            ?? appModel.loadedExperience?.document.id
            ?? "No experience loaded"
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
