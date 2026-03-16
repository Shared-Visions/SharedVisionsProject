//
//  AboutView.swift
//  SharedVisions
//
//  Created by Joseph Simpson on 3/16/26.
//

import SwiftUI

struct AboutView: View {

    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        List {
            Section("General") {
                LabeledContent("App Name", value: "Shared Visions")
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }

            Section("Credits") {
                Text("Produced by the Shared Visions Community")
                Text("Powered by Love")
            }

            Section("Developer") {
                Toggle("Debug Mode", isOn: $appModel.useDebugMode)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    AboutView()
        .environment(AppModel())
}
