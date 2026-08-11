//

//  LiveModeView.swift
//  SharedVisions
//
//  Phase 5: drop-down picker that browses for `_maestro._tcp` services on
//  the LAN and connects the player to the chosen MaestroStudio. Shown as a
//  toolbar button in `PlaybackView`.
//

import SwiftUI
import ChapterPlayer

struct LiveModeView: View {
    @Environment(PlayerModel.self) private var appModel
    @StateObject private var browser = LiveServerBrowser()
    @State private var isOpen: Bool = false

    var body: some View {
        Menu {
            if browser.services.isEmpty {
                Text("No Maestro instances on the LAN.")
                Text("Open MaestroStudio on a Mac on the same Wi-Fi.")
                    .font(.caption)
            } else {
                ForEach(browser.services) { descriptor in
                    Button {
                        Task {
                            // Set the flag *before* opening the immersive
                            // space so ImmersiveView's mount-time auto-play
                            // skips the bundled documentary and waits for
                            // the live fetch to land.
                            appModel.isLoadingLiveExperience = true
                            if appModel.immersiveSpaceState == .closed {
                                await appModel.transitionToPhase("immersive")
                            }
                            if appModel.immersiveSpaceState == .open {
                                await appModel.playLiveExperience(from: descriptor)
                            } else {
                                // Failed to open the space — clear the flag
                                // so a future bundled-doc auto-play isn't
                                // permanently suppressed.
                                appModel.isLoadingLiveExperience = false
                            }
                        }
                    } label: {
                        Label(descriptor.serviceName, systemImage: "dot.radiowaves.left.and.right")
                    }
                }
            }
            if appModel.liveSubscription != nil {
                Divider()
                Button("Disconnect from live") {
                    appModel.stopLiveSubscription()
                }
            }
            if let err = browser.error {
                Divider()
                Text(err).foregroundStyle(.red)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: appModel.liveSubscription != nil
                      ? "dot.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right")
                    .foregroundStyle(appModel.liveSubscription != nil ? Color.green : Color.secondary)
                if appModel.livePrefetchProgress.isPrefetching {
                    Text("Streaming \(appModel.livePrefetchProgress.completedCount)/\(appModel.livePrefetchProgress.totalCount)")
                        .font(.caption.monospacedDigit())
                } else if let descriptor = appModel.liveSubscriptionDescriptor {
                    Text(descriptor.serviceName)
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Text("Live")
                        .font(.caption)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Discover and connect to a MaestroStudio on the LAN")
        .onAppear { browser.start() }
        .onDisappear { browser.stop() }
    }
}
