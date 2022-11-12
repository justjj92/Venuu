//
//  BgdFullScreen.swift
//  Venuu
//
//  Created by J J on 9/13/22.
//

import SwiftUI
import AVFoundation

public struct BgdFullScreenVideoView: View {
    @State private var player = AVQueuePlayer()
    private let videoName: String
    
    public init(videoName: String) {
        self.videoName = videoName
    }
    
    public var body: some View {
        GeometryReader { geo in
            PlayerView(videoName: videoName, player: player)
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    player.pause()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    player.play()
                }
        }
        .ignoresSafeArea()
    }
}

struct BackgroundFullScreenVideo_Previews: PreviewProvider {
    static var previews: some View {
        BgdFullScreenVideoView(videoName: "intro3")
    }
}
