import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

public struct BitcoinRegimeLogoLockup: View {
    private let markSize: CGFloat

    public init(markSize: CGFloat = 78) {
        self.markSize = markSize
    }

    public var body: some View {
        HStack(spacing: 18) {
            BitcoinRegimeLogoMark(size: markSize)

            VStack(alignment: .leading, spacing: 6) {
                Text("Bitcoin Regime Navigator")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Quiet market context at a glance.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.70))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct BitcoinRegimeLogoMark: View {
    private let size: CGFloat

    public init(size: CGFloat = 78) {
        self.size = size
    }

    public var body: some View {
        Group {
            if let logoImage = resolvedLogoImage {
                logoImage
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Color(red: 0.18, green: 0.20, blue: 0.26))
                    .overlay {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: size * 0.48, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.92))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: max(1, size * 0.018))
        }
        .shadow(color: Color.black.opacity(0.28), radius: size * 0.18, y: size * 0.06)
        .accessibilityHidden(true)
    }

    private var resolvedLogoImage: Image? {
        let platformImage: PlatformImage?

        #if canImport(UIKit)
        platformImage = PlatformImage(named: "BrandLogo", in: .main, compatibleWith: nil)
            ?? Bundle.module.url(forResource: "brand-logo-square", withExtension: "jpg")
                .flatMap { PlatformImage(contentsOfFile: $0.path) }
        #elseif canImport(AppKit)
        platformImage = Bundle.main.image(forResource: NSImage.Name("BrandLogo"))
            ?? Bundle.module.url(forResource: "brand-logo-square", withExtension: "jpg")
                .flatMap { PlatformImage(contentsOfFile: $0.path) }
        #else
        platformImage = nil
        #endif

        guard let platformImage else {
            return nil
        }

        #if canImport(UIKit)
        return Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        return Image(nsImage: platformImage)
        #else
        return nil
        #endif
    }
}
