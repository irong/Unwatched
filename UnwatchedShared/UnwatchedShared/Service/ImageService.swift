//
//  ImageService.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI
import OSLog


public struct ImageService {
    public static func persistImages(
        cache: [String: ImageCacheInfo]
    ) async {
        let container = DataProvider.shared.imageContainer
        let context = ModelContext(container)

        for info in cache.values {
            let imageCache = CachedImage(info.url, imageData: info.data)
            context.insert(imageCache)
            Logger.log.info("saved image with URL: \(info.url)")

        }

        try? context.save()
    }

    public static func storeImages(for infos: [NotificationInfo]) {
        let images = infos.compactMap { info in
            if let sendableVideo = info.video,
               let url = sendableVideo.thumbnailUrl,
               let data = sendableVideo.thumbnailData {
                return (url: url, data: data)
            }
            return nil
        }

        storeImages(images)
    }

    public static func storeImages(_ images: [(url: URL, data: Data)]) {
        Task.detached {
            let container = DataProvider.shared.imageContainer
            let context = ModelContext(container)

            for (url, data) in images {
                let image = CachedImage(url, imageData: data)
                context.insert(image)
            }
            try? context.save()
        }
    }

    public static func deleteImages(_ urls: [URL]) {
        Task {
            let imageContainer = DataProvider.shared.imageContainer
            let context = ModelContext(imageContainer)
            for url in urls {
                if let image = getCachedImage(for: url, context) {
                    context.delete(image)
                }
            }
            try? context.save()
        }
    }

    public static func getCachedImage(for url: URL, _ modelContext: ModelContext) -> CachedImage? {
        var fetch = FetchDescriptor<CachedImage>(predicate: #Predicate {
            $0.imageUrl == url
        })
        fetch.fetchLimit = 1
        return try? modelContext.fetch(fetch).first
    }

    public static func deleteAllImages() -> Task<(), Error> {
        return Task {
            let imageContainer = DataProvider.shared.imageContainer
            let context = ModelContext(imageContainer)
            let fetch = FetchDescriptor<CachedImage>()
            let images = try context.fetch(fetch)
            for image in images {
                context.delete(image)
            }
            try context.save()
        }
    }

    public static func loadImageData(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    public static func isYtShort(_ imageData: Data) -> Bool? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // check if every xth pixel at the bottom is black
        let size = image.size

        // top and bottom of a regular video thumbnail is a black bar
        let width = size.width
        let height = size.height

        let topY = height / 30
        let topBottomY = height / 12

        let centerX = width / 2
        let xDist = width / 6

        let points: [CGPoint] = [
            // top      ° . °
            // image
            // bottom   . ° .

            CGPoint(x: centerX, y: topBottomY),
            CGPoint(x: centerX, y: height - topBottomY),

            CGPoint(x: centerX + xDist, y: topY),
            CGPoint(x: centerX - xDist, y: topY),

            CGPoint(x: centerX + xDist, y: height - topY),
            CGPoint(x: centerX - xDist, y: height - topY)
        ]

        let colors = image.pixelColors(at: points)
        for color in colors where !color.isBlack() {
            return true
        }
        return false
    }
}

//// shorts detection
//#Preview {
//    // let url = URL(string: "https://i2.ytimg.com/vi/9pVd8_bjl1o/hqdefault.jpg")!
//    let url = URL(string: "https://i3.ytimg.com/vi/jxmXQcYY1Sw/hqdefault.jpg")! // short
//
//    guard let data = try? Data(contentsOf: url),
//          let myImage = UIImage(data: data) else {
//        return ZStack { }
//    }
//    let isShort = ImageService.isYtShort(data)
//
//    let color = myImage.pixelColors(at: [CGPoint(x: 200, y: 200)])
//    let isBlack = color[0].isBlack()
//
//    return VStack {
//        Image(uiImage: myImage)
//        Text(verbatim: "IS BLACK: \(isBlack)")
//        Text(verbatim: "IS BLACK: \(color)")
//        Text(verbatim: "IS SHORT: \(isShort)")
//    }
//}
