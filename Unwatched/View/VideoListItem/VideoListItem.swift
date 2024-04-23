//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

enum VideoActions {
    case queueTop
    case queueBottom
    case delete
    case clear
    case more
    case details
}

struct VideoListItem: View {
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.goToQueueOnPlay) var goToQueueOnPlay: Bool = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Environment(SheetPositionReader.self) private var sheetPos

    @State var showInfo = false

    let video: Video
    var showVideoStatus: Bool = false
    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var videoDuration: Double?
    var watched: Bool?
    var clearRole: ButtonRole?
    var queueRole: ButtonRole?
    var onChange: (() -> Void)?

    var videoSwipeActions: [VideoActions] = [.queueTop, .queueBottom, .clear, .more, .details]

    init(video: Video,
         videoSwipeActions: [VideoActions]? = nil,
         videoDuration: Double? = nil,
         clearRole: ButtonRole? = nil,
         queueRole: ButtonRole? = nil,
         onChange: (() -> Void)? = nil) {
        self.video = video
        if let actions = videoSwipeActions {
            self.videoSwipeActions = actions
        }
        self.videoDuration = videoDuration
        self.clearRole = clearRole
        self.queueRole = queueRole
        self.onChange = onChange
    }

    init(video: Video,
         showVideoStatus: Bool,
         hasInboxEntry: Bool,
         hasQueueEntry: Bool,
         watched: Bool,
         videoSwipeActions: [VideoActions]? = nil,
         onClear: (() -> Void)? = nil) {
        self.video = video
        self.showVideoStatus = showVideoStatus
        self.hasInboxEntry = hasInboxEntry
        self.hasQueueEntry = hasQueueEntry
        self.watched = watched
        if let actions = videoSwipeActions {
            self.videoSwipeActions = actions
        }
    }

    var body: some View {
        videoItem
            .contentShape(Rectangle())
            .onTapGesture {
                player.playVideo(video)
                _ = VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
                if hideMenuOnPlay {
                    withAnimation {
                        navManager.showMenu = false
                    }
                }

                if goToQueueOnPlay {
                    navManager.navigateToQueue()
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                getLeadingSwipeActions()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                getTrailingSwipeActions()
            }
            .sheet(isPresented: $showInfo) {
                NavigationStack {
                    ScrollView {
                        DescriptionDetailView(video: video)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showInfo = false
                            } label: {
                                Image(systemName: Const.clearSF)
                            }
                        }
                    }
                }
                .presentationDragIndicator(.visible)
            }
    }

    var videoItem: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 8) {
                CachedImageView(imageHolder: video) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 168, height: 94.5)
                        .clipped()
                } placeholder: {
                    Color.backgroundColor
                        .frame(width: 168, height: 94.5)
                }
                .clipShape(.rect(cornerRadius: 15.0))
                .padding(showVideoStatus ? 5 : 0)

                VideoListItemDetails(video: video, videoDuration: videoDuration)
            }
            if showVideoStatus {
                VideoListItemStatus(
                    video: video,
                    playingVideoId: player.video?.youtubeId,
                    hasInboxEntry: hasInboxEntry,
                    hasQueueEntry: hasQueueEntry,
                    watched: watched
                )
            }
        }
    }

    func getLeadingSwipeActions() -> some View {
        Group {
            if videoSwipeActions.contains(.queueTop) {
                Button(role: queueRole,
                       action: addVideoToTopQueue,
                       label: {
                        Image(systemName: "text.insert")
                       })
                    .tint(.teal)
            }
            if videoSwipeActions.contains(.queueBottom) {
                Button(role: queueRole,
                       action: addVideoToBottomQueue,
                       label: {
                        Image(systemName: "text.append")
                       })
                    .tint(.mint)
            }
        }
    }

    func getTrailingSwipeActions() -> some View {
        return Group {
            if videoSwipeActions.contains(.clear) &&
                (hasInboxEntry == true
                    || hasQueueEntry == true
                    || [NavigationTab.queue, NavigationTab.inbox].contains(navManager.tab)
                ) {
                Button(role: clearRole,
                       action: clearVideoEverywhere,
                       label: {
                        Image(systemName: Const.clearSF)
                       })
                    .tint(.black)
            }
            if videoSwipeActions.contains(.more) {
                moreMenu
            }
            if videoSwipeActions.contains(.details) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: Const.videoDescriptionSF)
                }
                .tint(Color(UIColor.lightGray))
            }
        }
    }

    var moreMenu: some View {
        Menu {
            Button(action: markWatched) {
                Image(systemName: Const.watchedSF)
                Text("markWatched")
            }
            Button(action: toggleBookmark) {
                let isBookmarked = video.bookmarkedDate != nil

                Image(systemName: "bookmark")
                    .environment(\.symbolVariants,
                                 isBookmarked
                                    ? .fill
                                    : .none)
                if isBookmarked {
                    Text("bookmarked")
                } else {

                    Text("addBookmark")
                }
            }
            if video.inboxEntry == nil {
                Button(action: moveToInbox) {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("moveToInbox")
                }
            }
            if let url = video.url {
                ShareLink(item: url)
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
        }
        .tint(.gray)
    }

    func addVideoToTopQueue() {
        Logger.log.info("addVideoTop")
        let order = video.queueEntry?.order
        let task = VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
        handlePotentialQueueChange(after: task, order: order)
        onChange?()
    }

    func moveToInbox() {
        let task = VideoService.moveVideoToInbox(video, modelContext: modelContext)
        handlePotentialQueueChange(after: task)
        onChange?()
    }

    func toggleBookmark() {
        VideoService.toggleBookmark(video, modelContext)
        onChange?()
    }

    func markWatched() {
        let task = VideoService.markVideoWatched(video, modelContext: modelContext)
        handlePotentialQueueChange(after: task)
        onChange?()
    }

    func addVideoToBottomQueue() {
        Logger.log.info("addVideoBottom")
        let order = video.queueEntry?.order
        let task = VideoService.addToBottomQueue(video: video, modelContext: modelContext)
        handlePotentialQueueChange(after: task, order: order)
        onChange?()
    }

    func clearVideoEverywhere() {
        let order = video.queueEntry?.order
        let task = VideoService.clearFromEverywhere(
            video,
            updateCleared: true,
            modelContext: modelContext
        )
        handlePotentialQueueChange(after: task, order: order)
        onChange?()
    }

    func handlePotentialQueueChange(after task: Task<(), Error>, order: Int? = nil) {
        if order == 0 || video.queueEntry?.order == 0 {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }
}

#Preview {
    let container = DataController.previewContainer
    let context = ModelContext(container)
    let fetch = FetchDescriptor<Video>()
    let videos = try? context.fetch(fetch)
    guard let video = videos?.first else {
        return Text("noVideoFound")
    }

    return List {
        VideoListItem(
            video: video,
            showVideoStatus: true,
            hasInboxEntry: false,
            hasQueueEntry: true,
            watched: true
        )
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(SheetPositionReader())
    .environment(ImageCacheManager())
}
