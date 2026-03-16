//
//  ToggleDebugWindowButton.swift
//  SharedVisions
//
//  Created by Joseph Simpson on 3/16/26.
//

import SwiftUI

struct ToggleDebugWindowButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button {
            switch appModel.debugWindowState {
                case .open:
                    dismissWindow(id: appModel.debugWindowID)

                case .closed:
                    openWindow(id: appModel.debugWindowID)
            }
        } label: {
            Image(systemName: appModel.debugWindowState == .open ? "ladybug" : "ladybug.fill")
        }
        .fontWeight(.semibold)
    }
}
