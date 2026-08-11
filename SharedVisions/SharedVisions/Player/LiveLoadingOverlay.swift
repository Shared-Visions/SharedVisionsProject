//

//  LiveLoadingOverlay.swift
//  SharedVisions
//
//  Phase 5.5: full-cover loading state for `playLiveExperience`. Shows
//  while the player is fetching the document JSON, prefetching audio /
//  USDZ / image assets, and pre-rolling videos. Replaces the "frozen
//  timeline" feel from before — the user now gets a clear "Connecting
//  to Maestro on …" indicator with per-asset progress until the segment
//  is actually ready to play.
//

import SwiftUI
import ChapterPlayer

struct LiveLoadingOverlay: View {
    @Environment(PlayerModel.self) private var appModel
    @ObservedObject var prefetchProgress: LivePrefetchProgress

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // Spinner + headline
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(1.2)

                Text(headline)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let descriptor = appModel.liveLoadingDescriptor {
                    Text(descriptor.serviceName)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Per-asset prefetch progress
            if prefetchProgress.totalCount > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text(prefetchHeadline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(prefetchProgress.completedCount)/\(prefetchProgress.totalCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: prefetchProgress.fraction)
                        .progressViewStyle(.linear)
                    if prefetchProgress.totalBytes > 0 {
                        HStack(spacing: 6) {
                            Text(byteProgressString)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            if prefetchProgress.bytesPerSecond > 0 {
                                Text("·")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(speedString)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            // Error surfacing
            if let error = appModel.liveLoadError {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            Text("Keep MaestroStudio open on the same Wi-Fi.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: - Derived

    private var headline: String {
        if appModel.liveLoadError != nil { return "Couldn't connect" }
        if prefetchProgress.isPrefetching { return "Streaming assets" }
        return "Connecting to live"
    }

    private var prefetchHeadline: String {
        if prefetchProgress.completedCount < prefetchProgress.totalCount {
            return "Caching audio / models / images"
        }
        return "Pre-rolling videos"
    }

    private var byteProgressString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let done = formatter.string(fromByteCount: prefetchProgress.transferredBytes)
        let total = formatter.string(fromByteCount: prefetchProgress.totalBytes)
        return "\(done) / \(total)"
    }

    /// "12.3 MB/s" — formatted speed readout from the rolling sample
    /// `LivePrefetchProgress` keeps. Shown next to the byte counts when
    /// we have a positive sample so the bar isn't the only signal
    /// that work is happening.
    private var speedString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let bytes = Int64(prefetchProgress.bytesPerSecond)
        return "\(formatter.string(fromByteCount: bytes))/s"
    }
}
