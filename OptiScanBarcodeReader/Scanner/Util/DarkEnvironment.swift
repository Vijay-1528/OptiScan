//
//  DarkEnvironmentUtils.swift
//  OptiScanBarcodeReader
//
//  Created by MAC-OBS-25 on 28/02/22.
//

import UIKit
import opencv2
import VideoToolbox

extension CVPixelBuffer{
    
    func getCurrentMillis()->String {
       let dateFormatter : DateFormatter = DateFormatter()
       dateFormatter.dateFormat = "yyyy-MMM-dd HH:mm:ss.SSSS"
       let date = Date()
       let dateString = dateFormatter.string(from: date)
       return dateString
   }
    func setBrightnessContrastOpencv() -> CVPixelBuffer{
        print("BEFORE setBrightnessContrastOpencv: \(getCurrentMillis())")
        let sourceImage = self.toImage()
        
        let src = Mat(uiImage: sourceImage)
        src.convert(to: src, rtype: -1, alpha: 1.2, beta: 1)
        let resultImage = src.toUIImage()
        return resultImage.toPixelBuffer()
       
    }
    
    func setBrightnessContrastAndroidOpencv() -> CVPixelBuffer{
        var img = Mat()
        let thresh = Mat()
        let sourceImage = self.toImage()
        img = Mat(uiImage: sourceImage)
        let lookUpTable = Mat(rows: 1, cols: 256, type: CvType.CV_8U)
        let lookUpTableTotal = lookUpTable.total()
        let lookUpTableChannels = Int(lookUpTable.channels())
        let arrayCount =  lookUpTableTotal * lookUpTableChannels
        var lookUpTableData = [UInt8](repeating: 0, count: arrayCount)
        for i in 0 ... lookUpTable.cols() - 1 {
            let power = pow(Double(i) / 255.0, 0.4) * 255.0
            lookUpTableData[Int(i)] = UInt8(power)
            print(i)
        }
        do {
            try  lookUpTable.put(row: 0, col: 0, data: lookUpTableData)
        } catch {
            print("error")
        }
        Core.LUT(src: img, lut: lookUpTable, dst: thresh)
        let res = thresh.toCGImage()
        let resImage = UIImage(cgImage: res)
        return resImage.toPixelBuffer()
    }
    
    func toImage() -> UIImage{
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        guard let cgImage = cgImage else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
    
}

extension UIImage {
    
    func toPixelBuffer() -> CVPixelBuffer{
        let cgimage = self.cgImage
        let frameSize = CGSize(width: self.size.width, height: self.size.height)
        var pixelBuffer:CVPixelBuffer? = nil
        let _ = CVPixelBufferCreate(kCFAllocatorDefault, Int(cgimage?.width ?? 0), Int(cgimage?.height ?? 0), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        
        context?.draw(cgimage!, in: CGRect(x: 0, y: 0, width: cgimage?.width ?? 0, height: cgimage?.height ?? 0))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer!
        
    }
    

}
