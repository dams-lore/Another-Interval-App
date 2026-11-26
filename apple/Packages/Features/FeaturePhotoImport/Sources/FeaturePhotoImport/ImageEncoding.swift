import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Réduit et compresse la photo avant l'envoi à l'IA (moins de données, plus rapide, moins cher).
public enum ImageEncoding {
    public static func jpegData(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return data }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
        #else
        return data
        #endif
    }
}
