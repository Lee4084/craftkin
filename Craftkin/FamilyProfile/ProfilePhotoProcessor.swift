import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProfilePhotoError: Error, LocalizedError {
    case tooLarge, invalidImage
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Choose a photo smaller than 20 MB."
        case .invalidImage: "This photo could not be opened. Choose another image."
        }
    }
}

enum ProfilePhotoProcessor {
    static func jpeg(from data: Data) throws -> Data {
        guard data.count <= 20 * 1024 * 1024 else { throw ProfilePhotoError.tooLarge }
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source), UTType(type as String)?.conforms(to: .image) == true,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
              ] as CFDictionary) else { throw ProfilePhotoError.invalidImage }
        // Re-encode pixels only: original EXIF/location metadata is not copied.
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ProfilePhotoError.invalidImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ProfilePhotoError.invalidImage }
        return output as Data
    }
}
