import Foundation
import SwiftUI

#if os(macOS)
import AppKit
private let petImageCache = NSCache<NSString, NSImage>()
#else
import UIKit
private let petImageCache = NSCache<NSString, UIImage>()
#endif

struct PetSprite: View {
    let pet: Pet

    static func horizontalScale(facingRight: Bool) -> CGFloat {
        facingRight ? -1 : 1
    }

    private var currentFrameName: String? {
        guard pet.character.frameNames.indices.contains(pet.frameIndex) else { return nil }
        return pet.character.frameNames[pet.frameIndex]
    }

    private var image: Image {
        guard let currentFrameName,
              let url = Bundle.module.url(forResource: currentFrameName, withExtension: "png") else {
            return Image(systemName: "questionmark.circle.fill")
        }

        #if os(macOS)
        if let cached = petImageCache.object(forKey: currentFrameName as NSString) {
            return Image(nsImage: cached)
        }
        guard let source = NSImage(contentsOf: url) else {
            return Image(systemName: "questionmark.circle.fill")
        }
        petImageCache.setObject(source, forKey: currentFrameName as NSString)
        return Image(nsImage: source)
        #else
        if let cached = petImageCache.object(forKey: currentFrameName as NSString) {
            return Image(uiImage: cached)
        }
        guard let source = UIImage(contentsOfFile: url.path) else {
            return Image(systemName: "questionmark.circle.fill")
        }
        petImageCache.setObject(source, forKey: currentFrameName as NSString)
        return Image(uiImage: source)
        #endif
    }

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 150)
            .scaleEffect(x: Self.horizontalScale(facingRight: pet.facingRight), y: 1)
            .accessibilityLabel("\(pet.character.displayName)，正在爬行")
    }
}
