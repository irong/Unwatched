//
//  VideoListItemStatus.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemStatus: View {
    var video: Video
    var playingVideoId: String?

    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var watched: Bool?

    var body: some View {
        if let statusInfo = videoStatusSystemName,
           let status = statusInfo.status {
            Image(systemName: status)
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, statusInfo.color)
                .frame(width: 23, height: 23)
        }
    }

    var videoStatusSystemName: (status: String?, color: Color)? {
        let defaultColor = Color.green
        if video.youtubeId == playingVideoId {
            return ("play.circle.fill", defaultColor)
        }
        if hasInboxEntry == true {
            return ("circle.circle.fill", .mint)
        }
        if hasQueueEntry == true {
            return ("arrow.uturn.right.circle.fill", defaultColor)
        }
        if watched == true {
            return (Const.watchedSF, defaultColor)
        }
        return nil
    }
}

#Preview {
    VideoListItemStatus(
        video: Video.getDummy(),
        hasInboxEntry: true,
        hasQueueEntry: false,
        watched: false
    )
}
