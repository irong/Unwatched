import SwiftData
import SwiftUI
import Observation

class VideoService {
    static func loadNewVideosInBg(subscriptionIds: [PersistentIdentifier]? = nil, container: ModelContainer) -> Task<(), Error> {
        print("loadNewVideosInBg")
        let task = Task.detached {
            let repo = VideoActor(modelContainer: container)
            do {
                try await repo.loadVideos(
                    subscriptionIds
                )
            } catch {
                print("\(error)")
                throw error
            }
        }
        return task
    }

    static func markVideoWatched(_ video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.id
        let task = Task {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.markVideoWatched(videoId)
            } catch {
                print("\(error)")
                throw error
            }
        }
        return task
    }

    static func moveQueueEntry(from source: IndexSet, to destination: Int, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let task = Task.detached {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.moveQueueEntry(from: source, to: destination)
            } catch {
                print("\(error)")
                throw error
            }
        }
        return task
    }

    static func moveVideoToInbox(_ video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.id
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.moveVideoToInbox(videoId)
        }
        return task
    }

    static func deleteInboxEntries(_ entries: [InboxEntry], modelContext: ModelContext) {
        for entry in entries {
            VideoService.deleteInboxEntry(entry, modelContext: modelContext)
        }
    }

    static func deleteInboxEntry(_ entry: InboxEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
    }

    static func deleteQueueEntry(_ entry: QueueEntry, modelContext: ModelContext) {
        VideoActor.deleteQueueEntry(entry, modelContext: modelContext)
    }

    static func clearFromEverywhere(_ video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.id
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.clearEntries(from: videoId)
        }
        return task
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoIds = videos.map { $0.id }
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.insertQueueEntries(at: index, videoIds: videoIds)
        }
        return task
    }

    static func addToBottomQueue(video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.persistentModelID
        let task = Task {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.addToBottomQueue(videoId: videoId)
            } catch {
                print("addToBottomQueue: \(error)")
                throw error
            }
        }
        return task
    }

    static func addForeignUrls(_ urls: [URL],
                               in videoPlacement: VideoPlacement,
                               at index: Int = 1,
                               container: ModelContainer) -> Task<(), Error> {
        print("addForeignUrls")

        let task = Task.detached {
            let repo = VideoActor(modelContainer: container)
            try await repo.addForeignVideo(from: urls, in: videoPlacement, at: index)
        }
        return task
    }

    static func updateDuration(_ video: Video, duration: Double) {
        if let last = video.sortedChapters.last {
            last.endTime = duration
            last.duration = duration - last.startTime
        }
        video.duration = duration
    }

    static func getTopVideoInQueue(_ modelContext: ModelContext) -> Video? {
        let sort = SortDescriptor<QueueEntry>(\.order)
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
        fetch.fetchLimit = 1
        let videos = try? modelContext.fetch(fetch)
        if let nextVideo = videos?.first {
            return nextVideo.video
        }
        return nil
    }

    static func getNextVideoInQueue(_ modelContext: ModelContext) -> Video? {
        let sort = SortDescriptor<QueueEntry>(\.order)
        let fetch = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.order > 0 }, sortBy: [sort])
        let videos = try? modelContext.fetch(fetch)
        if let nextVideo = videos?.first {
            return nextVideo.video
        }
        return nil
        // TODO: worth putting this on the background thread?
        // TODO: worth getting the actual queueEntry for the current video first and then continue?
    }

    static func deleteEverything(_ container: ModelContainer) async {
        let context = ModelContext(container)
        do {
            try context.delete(model: QueueEntry.self)
            try context.delete(model: InboxEntry.self)
            try context.delete(model: WatchEntry.self)
            try context.delete(model: CachedImage.self)
            try context.delete(model: Subscription.self)
            try context.delete(model: Video.self)
            try context.save()
        } catch {
            print("Failed to clear everything")
        }
    }

    static func toggleBookmark(_ video: Video, _ context: ModelContext) {
        video.bookmarkedDate = video.bookmarkedDate == nil ? .now : nil
    }
}
