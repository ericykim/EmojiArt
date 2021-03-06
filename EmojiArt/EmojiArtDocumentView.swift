//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by CS193p Instructor on 4/26/21.
//  Copyright © 2021 Stanford University. All rights reserved.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                documentBody
                conditionalDeleteEmojiButton.padding(.vertical).transition(.opacity)
            }
            palette
        }
    }
    
    @ViewBuilder
    private var conditionalDeleteEmojiButton: some View {
        if !selectedEmojis.isEmpty {
            Button {
                withAnimation {
                    for emoji in selectedEmojis {
                        document.removeEmoji(emoji)
                    }
                    selectedEmojis.removeAll()
                }
            } label: {
                Label("Delete Selected Emojis", systemImage: "trash")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.red)
            }
            .padding(.horizontal)
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                )
                    .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: singleTapToDeselectAllEmoji()))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        
                        Text(emoji.text)
                            .border(.red, width: selectedEmojis.containsMatching(emoji) ? 2 : 0)
                            .font(.system(size: fontSize(for: emoji)))
                            .scaleEffect(scale(for: emoji))
                            .scaleEffect(zoomScale)
                            .position(position(for: emoji, in: geometry))
                            .offset(selectedEmojis.containsMatching(emoji) ? gestureEmojiPanOffset :.zero )
                            .onTapGesture {
                                withAnimation {
                                    selectedEmojis.toggleMatching(emoji)
                                }
                            }
                            .gesture(panGesture(for: emoji))
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText,.url,.image], isTargeted: nil) { providers, location in
                drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture().simultaneously(with: zoomGesture()))
            .onTapGesture {
                deselectAllEmoji()
            }
        }
    }
    
    // MARK: - Selection and Deselection
    @State private var selectedEmojis = Set<EmojiArtModel.Emoji>()

    private func singleTapToDeselectAllEmoji() -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis.removeAll()
                }
            }
    }
    
    private func isSelectedEmoji(_ emoji: EmojiArtModel.Emoji) -> Bool {
        selectedEmojis.contains(emoji)
    }
    
    private func deselectAllEmoji() {
        selectedEmojis.removeAll()
    }
    
    private func anyEmojisSelected() -> Bool {
        !selectedEmojis.isEmpty
    }
    
    
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    // MARK: - Positioning/Sizing Emoji
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    // MARK: - Zooming
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    @GestureState private var gestureEmojiZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func scale(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        selectedEmojis.containsMatching(emoji) ? (zoomScale * gestureEmojiZoomScale) : zoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                if selectedEmojis.isEmpty {
                    gestureZoomScale = latestGestureScale
                }
            }
            .updating($gestureEmojiZoomScale) { latestEmojiGestureScale, gestureEmojiZoomScale, _ in
                if !selectedEmojis.isEmpty {
                    gestureEmojiZoomScale = latestEmojiGestureScale
                }
            }
            .onEnded { gestureScaleAtEnd in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: gestureScaleAtEnd)
                    }
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0  {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Panning
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    @GestureState private var gestureEmojiPanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture(for emoji: EmojiArtModel.Emoji? = nil) -> some Gesture {
        if let emoji = emoji, selectedEmojis.containsMatching(emoji) {
            return DragGesture()
                .updating($gestureEmojiPanOffset) { latestDragValue, gestureEmojiPanOffset, _ in
                    gestureEmojiPanOffset = latestDragValue.translation
                }
                .onEnded { finalDragValue in
                    for emoji in selectedEmojis {
                        document.moveEmoji(emoji, by: finalDragValue.translation / zoomScale)
                    }
                    
                }
        } else {
            return DragGesture()
                .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                    gesturePanOffset = latestDragGestureValue.translation / zoomScale
                }
                .onEnded { finalDragGestureValue in
                    steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
                }
        }

    }
    
    // MARK: - Palette
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
    
}

struct ScrollingEmojisView: View {
    let emojis: String
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
