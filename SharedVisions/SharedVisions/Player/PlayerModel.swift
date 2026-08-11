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

    init() {
        super.init(
            immersiveSpaceID: Self.chapterSpaceID,
            ambientBackdropName: nil
        )
    }
}
