//
//  AppModel.swift
//  SharedVisions
//
//  Created by Jeffrey Berthiaume on 3/6/26.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {

    // TODO: We need a way to turn this off by default, but enable it when needed
    var useDebugMode = true

    // MARK: Scene Management State
    var mainWindowID = "MainWindow"
    var mainStorySpaceID = "MainStorySpace"
    var debugWindowID = "DebugWindow"

    enum WindowState {
        case closed
        case open
    }

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var mainWindowState = WindowState.closed
    var mainStorySpaceState = ImmersiveSpaceState.closed
    var progressiveSpaceRange: ImmersionStyle = .progressive(0.4...0.8, initialAmount: 1.0, aspectRatio: .landscape)
    var debugWindowState: WindowState = .closed

    // MARK: TBD
}
