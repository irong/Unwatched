//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ContentView: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        @Bindable var navManager = navManager
        let videoExists = player.video != nil
        let bigScreen = sizeClass == .regular && !UIDevice.isIphone

        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let layout = isLandscape
                ? AnyLayout(HStackLayout())
                : AnyLayout(VStackLayout())
            let landscapeFullscreen = !bigScreen && isLandscape

            let chapterViewDetent: Set<PresentationDetent> = player.embeddingDisabled
                ? [.medium]
                : [.height(sheetPos.playerControlHeight)]
            let sidebarWidth: Double = dynamicTypeSize >= .accessibility1 ? 410 : 360

            ZStack {
                layout {
                    VideoPlayer(
                        compactSize: bigScreen,
                        showInfo: !bigScreen || (isLandscape && bigScreen) && !hideControlsFullscreen,
                        horizontalLayout: hideControlsFullscreen,
                        landscapeFullscreen: landscapeFullscreen
                    )
                    .frame(maxHeight: .infinity)

                    if bigScreen && !hideControlsFullscreen {
                        MenuView(isSidebar: true)
                            .frame(maxWidth: isLandscape
                                    ? min(proxy.size.width * 0.4, sidebarWidth)
                                    : nil,
                                   maxHeight: isLandscape
                                    ? nil
                                    : proxy.size.height * 0.4)
                            .setColorScheme()
                            .if(isLandscape) { view in
                                view.clipShape(RoundedRectangle(
                                    cornerRadius: 9, style: .continuous
                                ))
                            }
                            .edgesIgnoringSafeArea(.all)
                    }
                }
                if !bigScreen && !videoExists {
                    VideoNotAvailableView()
                }
            }
            .animation(.default, value: hideControlsFullscreen)
            .background(Color.playerBackgroundColor)
            .environment(\.colorScheme, .dark)
            .onChange(of: proxy.safeAreaInsets.top, initial: true) {
                if !landscapeFullscreen {
                    sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
                }
            }
            .sheet(isPresented: $navManager.showDescriptionDetail) {
                if let video = player.video {
                    ChapterDescriptionView(video: video)
                        .presentationDetents(bigScreen ? [] : chapterViewDetent)
                        .presentationBackgroundInteraction(
                            bigScreen
                                ? .disabled
                                :
                                .enabled(upThrough: .height(sheetPos.playerControlHeight))
                        )
                        .presentationDragIndicator(.hidden)
                        .environment(\.colorScheme, colorScheme)
                }
            }
            .menuViewSheet(
                allowMaxSheetHeight: videoExists && !navManager.searchFocused,
                allowPlayerControlHeight: !player.embeddingDisabled
                    && player.videoAspectRatio > Const.tallestAspectRatio,
                landscapeFullscreen: landscapeFullscreen,
                disableSheet: bigScreen
            )
        }
        .setColorScheme()
        .ignoresSafeArea(bigScreen ? .keyboard : [])
        .onSizeChange { newSize in
            sheetPos.sheetHeight = newSize.height
        }
    }
}

#Preview {
    ContentView(hideControlsFullscreen: false)
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager.getDummy(true))
        .environment(Alerter())
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader.shared)
    // .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
