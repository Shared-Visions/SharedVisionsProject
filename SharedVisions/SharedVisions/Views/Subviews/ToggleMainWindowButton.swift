//
//  ToggleMainWindowButton.swift
//  SharedVisions
//
//  Created by Joseph Simpson on 3/16/26.
//

import SwiftUI

struct ToggleMainWindowButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button {
            switch appModel.mainWindowState {
                case .open:
                    dismissWindow(id: appModel.mainWindowID)

                case .closed:
                    openWindow(id: appModel.mainWindowID)
            }
        } label: {
            Text(appModel.mainWindowState == .open ? "Hide Main Window" : "Show Main Window")
        }
        .fontWeight(.semibold)
    }
}
