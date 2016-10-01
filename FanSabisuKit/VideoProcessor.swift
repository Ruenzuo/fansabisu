import Foundation
import AVFoundation
import ImageIO
import MobileCoreServices
import Photos

enum VideoProcessorError: Error {
    case InvalidDestination
    case ProcessingFailed
}

public class VideoProcessor {
    
    public init() {
    }
    
    public func processVideo(with fileURL: URL, completionHandler: @escaping (Result<URL>) -> Void) {
        let asset = AVAsset(url: fileURL)
        let videoLength = CMTimeGetSeconds(asset.duration)
        let requiredFrames = Int(videoLength * 24)
        let step = Float(asset.duration.value) / Float(requiredFrames)
        var currentTime: Int64 = 0
        var frames = [UIImage]()
        for _ in 1...requiredFrames {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.requestedTimeToleranceAfter = kCMTimeZero;
            generator.requestedTimeToleranceBefore = kCMTimeZero;
            generator.appliesPreferredTrackTransform = true;
            
            let time = CMTimeMake(currentTime, asset.duration.timescale)
            if let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) {
                let image = UIImage(cgImage: imageRef)
                frames.append(image)
            }
            
            currentTime += Int64(step)
        }
        
        let temporaryDirectoryFilePath = URL(fileURLWithPath: NSTemporaryDirectory())
        let temporaryURL = temporaryDirectoryFilePath.appendingPathComponent(fileURL.lastPathComponent.replacingOccurrences(of: ".mp4", with: ".gif"))
        
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
        let gifProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: Float(videoLength) / Float(requiredFrames)]]
        guard let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, kUTTypeGIF, requiredFrames, nil) else {
            return completionHandler(Result.Failure(VideoProcessorError.InvalidDestination))
        }
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        for frame in frames {
            if let cgImage = frame.cgImage {
                CGImageDestinationAddImage(destination, cgImage, gifProperties  as CFDictionary)
            }
        }
        
        if (!CGImageDestinationFinalize(destination)) {
            return completionHandler(Result.Failure(VideoProcessorError.ProcessingFailed))
        }
        
        PHPhotoLibrary.shared().performChanges({ 
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: temporaryURL)
        }) { (success, error) in
            DispatchQueue.main.async {
                completionHandler(Result.Success(temporaryURL))
            }
        }
    }
    
}
