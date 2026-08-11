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

    private func releaseBundleScope() {
        if bundleScopeActive, let openBundleURL {
            openBundleURL.stopAccessingSecurityScopedResource()
        }
        bundleScopeActive = false
        openBundleURL = nil
    }
}
