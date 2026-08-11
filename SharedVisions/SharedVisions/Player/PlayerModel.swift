//
//  PlayerModel.swift
//  SharedVisions
//
//  Thin product-side wrapper around `ChapterPlayer.ChapterPlayerCore`
//  for the ChapterScript player surface. Kept SEPARATE from `AppModel`
//  (the app-shell state) so the shell owns windows/tabs and this owns
//  the sequence engine, managers, and live-connect state. Views observe
//  it via `@Environment(PlayerModel.self)`.
//

import Foundation
import SwiftUI
import AVFoundation
import ChapterScript
import ChapterPlayer

@MainActor
@Observable
final class PlayerModel: ChapterPlayerCore {

    static let chapterSpaceID = "ChapterSpace"

    // MARK: - Open local bundle (session-scoped file access)

    /// The picked `.chapterscript` bundle, with its security scope HELD
    /// FOR THE WHOLE SESSION. The picker's URL only grants access while
    /// `startAccessingSecurityScopedResource` is balanced open — and
    /// playback reads media lazily (AVPlayer streams `assets/*` files
    /// continuously), so releasing the scope after load meant every
    /// video resolved to nil at step time ("file not found" with the
    /// file right there). Scope is released only when another bundle
    /// replaces it.
    private(set) var openBundleURL: URL?
    private var bundleScopeActive = false

    init() {
        super.init(
            immersiveSpaceID: Self.chapterSpaceID,
            ambientBackdropName: nil
        )
    }

    /// Open a picked `.chapterscript` directory: acquire (and keep) its
    /// security scope, enter the immersive space, load + play.
    func openLocalBundle(_ url: URL) async {
        releaseBundleScope()
        bundleScopeActive = url.startAccessingSecurityScopedResource()
        openBundleURL = url
        await transitionToPhase("immersive")
        await loadAndPlayLocalExperience(at: url)
    }

    // MARK: - Mute

    /// One switch for everything audible: the spatial audio mix bus and
    /// every video channel's AVPlayer referenced by the loaded document.
    private(set) var isMuted = false

    func toggleMuted() {
        isMuted.toggle()
        audioManager.isMuted = isMuted
        guard let document = loadedExperience?.document else { return }
        var channels: Set<String> = [Self.backdropVideoChannel]
        for sequence in document.sequences {
            for step in sequence.steps {
                for action in step.actions + step.scheduledActions.map(\.action) {
                    if case .playVideo(let dto) = action { channels.insert(dto.channel) }
                    if case .prepareVideo(let dto) = action { channels.insert(dto.channel) }
                }
            }
        }
        for channel in channels {
            videoManager.player(for: channel)?.isMuted = isMuted
        }
    }

    private func releaseBundleScope() {
        if bundleScopeActive, let openBundleURL {
            openBundleURL.stopAccessingSecurityScopedResource()
        }
        bundleScopeActive = false
        openBundleURL = nil
    }
}
