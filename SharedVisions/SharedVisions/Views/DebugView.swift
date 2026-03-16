//
//  DebugView.swift
//  SharedVisions
//
//  Created by Joseph Simpson on 3/16/26.
//

import SwiftUI

struct DebugView: View {
    @Environment(AppModel.self) private var appModel
    var body: some View {
        VStack {
            Text("Debug View (development only)")

            Divider()
            Text("Main Window State: \(String(describing: appModel.mainWindowState))")
            ToggleMainWindowButton()
            Divider()
            Text("Main Story Space: \(String(describing: appModel.mainStorySpaceState))")
            ToggleImmersiveSpaceButton()
        }
    }
}

#Preview {
    DebugView()
}
