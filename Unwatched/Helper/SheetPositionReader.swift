//
//  SheetPositionHandler.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog

private let log = Logger(subsystem: Const.bundleId, category: "SheetPositionReader")

@Observable class SheetPositionReader {
    // Sheet animation and height detection
    var swipedBelow: Bool = true
    var playerControlHeight: CGFloat = .zero
    @ObservationIgnored var selectedDetent: PresentationDetent?
    @ObservationIgnored var sheetHeight: CGFloat = .zero
    @ObservationIgnored private var sheetDistanceToTop: CGFloat = .zero

    static func load() -> SheetPositionReader {
        let sheetPos = SheetPositionReader()

        if let savedDetent = UserDefaults.standard.data(forKey: Const.selectedDetent),
           let loadedDetentEncoding = try? JSONDecoder().decode(PresentationDetentEncoding.self, from: savedDetent) {
            let detent = loadedDetentEncoding.toPresentationDetent()
            sheetPos.selectedDetent = detent
        }
        return sheetPos
    }

    func save() {
        let encoder = JSONEncoder()
        let detent = selectedDetent?.encode(playerControlHeight)

        if let encoded = try? encoder.encode(detent) {
            UserDefaults.standard.set(encoded, forKey: Const.selectedDetent)
        }
    }

    var maxSheetHeight: CGFloat {
        sheetHeight - Const.playerAboveSheetHeight
    }

    func setTopSafeArea(_ topSafeArea: CGFloat) {
        sheetDistanceToTop = topSafeArea + Const.playerAboveSheetHeight
    }

    func setDetentMiniPlayer() {
        log.info("setDetentMiniPlayer()")
        selectedDetent = .height(maxSheetHeight)
    }

    func setDetentVideoPlayer() {
        log.info("setDetentVideoPlayer()")
        selectedDetent = .height(playerControlHeight)
    }

    // global position changes
    func handleSheetMinYUpdate(_ minY: CGFloat) {
        let value = minY - sheetDistanceToTop
        let newBelow = value > 50 || minY == 0 // after dismissing the sheet minY becomes 0
        if newBelow != swipedBelow {
            swipedBelow = newBelow
        }
    }
}
