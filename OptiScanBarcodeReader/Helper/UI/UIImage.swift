//
//  UIImage.swift
//  OptiScanBarcodeReader
//
//  Created by Dineshkumar Kandasamy on 17/05/22.
//

import Foundation
import UIKit

extension UIImage {
    var brightness: Int {
        get {
            return self.cgImage?.brightnessValue ?? 0
        }
    }
}

extension UIImage {

    func imageResized(to size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func rotate(radians: Float) -> UIImage? {
        let size = CGSize(width: self.size.width + 200, height: self.size.height + 200)
        var newSize = CGRect(origin: CGPoint.zero, size: size).applying(CGAffineTransform(rotationAngle: CGFloat(radians * .pi / 180))).size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians * .pi / 180))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Returns the data representation of the image after scaling to the given `size` and converting
    /// to grayscale.
    ///
    /// - Parameters
    ///   - size: Size to scale the image to (i.e. image size used while training the model).
    /// - Returns: The scaled image as data or `nil` if the image could not be scaled.
    public func scaledData(with size: CGSize) -> Data? {
        guard let cgImage = self.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.none.rawValue)
        let _ = CGColorSpaceCreateDeviceRGB()
        
        let width = Int(size.width)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: Int(size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: width * 3,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        let _ = UIImage(cgImage: context.makeImage()!)
        
        guard let scaledBytes = context.makeImage()?.dataProvider?.data as Data? else { return nil }
        //    let scaledFloats = scaledBytes.map { Float32($0) / 255.0 }
        let scaledFloats = scaledBytes.map { (Float32($0) - 127.5) / 1.0 }
        
        let _ = UIImage(data: Data(copyingBufferOf: scaledFloats))
        
        return Data(copyingBufferOf: scaledFloats)
    }

     func from(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 414, height: 896)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
    
}



extension UIImage {
    convenience init(view: UIView) {
        UIGraphicsBeginImageContext(view.frame.size)
        view.layer.render(in:UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
    }
}
