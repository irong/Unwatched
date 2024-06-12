//
//  BrowserView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import TipKit
import OSLog

struct BrowserView: View, KeyboardReadable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false

    var url: Binding<BrowserUrl?> = .constant(nil)
    var startUrl: BrowserUrl?

    var showHeader: Bool = true
    var safeArea: Bool = true

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    var body: some View {
        let subscriptionText = browserManager.channelTextRepresentation

        GeometryReader { geometry in
            VStack {
                if showHeader {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(7)
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.neutralAccentColor)
                }

                ZStack {
                    YtBrowserWebView(url: url,
                                     startUrl: startUrl,
                                     browserManager: browserManager)
                    if !isKeyboardVisible {
                        VStack {
                            Spacer()
                            if subscriptionText == nil && browserManager.firstPageLoaded {
                                TipView(ytBrowserTip)
                                    .padding(.horizontal)
                            }

                            ZStack {
                                if let text = subscriptionText, !isKeyboardVisible {
                                    addSubButton(text)
                                        .popoverTip(addButtonTip, arrowEdge: .bottom)
                                        .disabled(subscribeManager.isLoading)
                                }

                                HStack {
                                    Spacer()
                                    AddVideoButton(videoUrl: browserManager.videoUrl)
                                        .padding(20)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Spacer()
                                .frame(height:
                                        (browserManager.isMobileVersion ? 60 : 0)
                                        + (safeArea ? geometry.safeAreaInsets.bottom : 0)
                                )
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: safeArea ? [.bottom] : [])
        }
        .background(Color.youtubeWebBackground)
        .task(id: browserManager.info?.channelId) {
            subscribeManager.reset()
            await subscribeManager.setIsSubscribed(browserManager.info)
        }
        .task(id: browserManager.info?.playlistId) {
            subscribeManager.reset()
            handleSubscriptionInfoChanged(browserManager.info)
            await subscribeManager.setIsSubscribed(browserManager.info)
        }
        .onChange(of: browserManager.info?.userName) {
            handleSubscriptionInfoChanged(browserManager.info)
        }
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            isKeyboardVisible = newIsKeyboardVisible
        }
        .onAppear {
            subscribeManager.container = modelContext.container
            Task {
                await subscribeManager.setIsSubscribed(browserManager.info)
            }
        }
        .onDisappear {
            if subscribeManager.hasNewSubscriptions {
                Task {
                    await refresher.refreshAll()
                }
            }
        }
    }

    func addSubButton(_ text: String) -> some View {
        VStack {
            if let error = subscribeManager.errorMessage {
                Button {
                    subscribeManager.errorMessage = nil
                } label: {
                    Text(verbatim: error)
                }
                .buttonStyle(CapsuleButtonStyle())
            }
            Button(action: handleAddSubButton) {
                HStack {
                    let systemName = subscribeManager.getSubscriptionSystemName()
                    Image(systemName: systemName)
                        .contentTransition(.symbolEffect(.replace))
                    Text(text)
                }
                .padding(10)
            }
            .buttonStyle(CapsuleButtonStyle(
                            background: Color.neutralAccentColor,
                            foreground: Color.backgroundColor))
            .bold()
        }
    }

    func handleSubscriptionInfoChanged(_ subscriptionInfo: SubscriptionInfo?) {
        Logger.log.info("handleSubscriptionInfoChanged")
        guard let info = subscriptionInfo else {
            Logger.log.info("no subscriptionInfo after change")
            return
        }
        let container = modelContext.container
        _ = SubscriptionService.isSubscribed(channelId: info.channelId,
                                             playlistId: info.playlistId,
                                             updateSubscriptionInfo: info,
                                             container: container)
    }

    func handleAddSubButton() {
        addButtonTip.invalidate(reason: .actionPerformed)
        ytBrowserTip.invalidate(reason: .actionPerformed)
        Task {
            await handleSubscriptionChange(browserManager.info)
        }
    }

    func handleSubscriptionChange(_ info: SubscriptionInfo?) async {
        Logger.log.info("handleSubscriptionChange")
        guard let isSubscribed = subscribeManager.isSubscribedSuccess,
              let subscriptionInfo = info else {
            Logger.log.info("handleAddSubButton without info/isSubscribed")
            return
        }
        if isSubscribed {
            await subscribeManager.unsubscribe(subscriptionInfo)
        } else {
            await subscribeManager.addSubscription(subscriptionInfo)
        }
    }
}

#Preview {
    BrowserView(startUrl: BrowserUrl.youtubeStartPage)
        .modelContainer(DataController.previewContainer)
        .environment(RefreshManager())
}
