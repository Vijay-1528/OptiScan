//
//  GammaCorrection.swift
//  OptiScanBarcodeReader
//
//  Created by MAC-OBS-25 on 30/03/22.
//

import Foundation
import opencv2

extension UIImage{
    
    func doGamma() -> UIImage {
        var resultImage:UIImage?
        let src = Mat(uiImage: self)
        src.convert(to: src, rtype: -1, alpha: 1.0, beta: 1.5)
        resultImage = src.toUIImage()
        return resultImage ?? self
    }
    

    func doGammaAndroid(red: Double, green: Double, blue: Double) -> UIImage{
        // create output image
        var bmOut = UIImage()
        // get image size
        let width = self.size.width
        let height = self.size.height
        // color information
        var A = Int()
        var R = Int()
        var G = Int()
        var B = Int()
        var pixel = Int()
        // constant value curve
        let MAX_SIZE = 256
        let MAX_VALUE_DBL = 255.0
        let MAX_VALUE_INT = 255
        let REVERSE = 1.0
        
        // gamma arrays
        var gammaR = [Int]()
        var gammaG = [Int]()
        var gammaB = [Int]()
        
        // setting values for every gamma channels
        for i in 0...MAX_SIZE {
            
            gammaR.append(min(MAX_VALUE_INT, Int((MAX_VALUE_DBL * pow(Double(i) / MAX_VALUE_DBL, REVERSE/red) + 0.5))))
            
            gammaG.append(min(MAX_VALUE_INT, Int((MAX_VALUE_DBL * pow(Double(i) / MAX_VALUE_DBL, REVERSE/green) + 0.5))))
            
            gammaB.append(min(MAX_VALUE_INT, Int((MAX_VALUE_DBL * pow(Double(i) / MAX_VALUE_DBL, REVERSE/blue) + 0.5))))
            
        }
        
//        var pixels = [PixelData]()
        
        // apply gamma table
        for x in 0...Int(width) {
            for y in 0...Int(height) {
//                // get pixel color
                let pixelValue = self.getPixelColor(x: x, y: y)

//                pixel = src.getPixel(x, y)
//                A = Color.alpha(pixel)
//                // look up gamma
//                R = gammaR[Color.red(pixel)]
//                G = gammaG[Color.green(pixel)]
//                B = gammaB[Color.blue(pixel)]
//                // set new color to output bitmap
//                bmOut.setPixel(x, y, Color.argb(A, R, G, B))
            }
        }
        
        
//        let pixelValue = self.getPixelColor(x: <#T##Int#>, y: <#T##Int#>)
        
        var pixels: [PixelData] = .init(repeating: .init(a: 0, r: 0, g: 0, b: 0), count: Int(width * height))

        
        for i in 0...gammaB.count-1 {
            let pixelValue = PixelData(a: 255, r: UInt8(gammaR[i]), g: UInt8(gammaG[i]), b: UInt8(gammaB[i]))
            
            
            pixels.append(pixelValue)
        }
        

        bmOut = UIImage(pixels: pixels, width: Int(width), height: Int(height))!

        
        return bmOut
    }
    
}

extension CGImage {
    func colors(at: [CGPoint]) -> [UIColor]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo),
            let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return at.map { p in
            let i = bytesPerRow * Int(p.y) + bytesPerPixel * Int(p.x)

            let a = CGFloat(ptr[i + 3]) / 255.0
            let r = (CGFloat(ptr[i]) / a) / 255.0
            let g = (CGFloat(ptr[i + 1]) / a) / 255.0
            let b = (CGFloat(ptr[i + 2]) / a) / 255.0

            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
    }
}

extension UIImage {
    convenience init?(pixels: [PixelData], width: Int, height: Int) {
        guard width > 0 && height > 0, pixels.count == width * height else { return nil }
        var data = pixels
        guard let providerRef = CGDataProvider(data: Data(bytes: &data, count: data.count * MemoryLayout<PixelData>.size) as CFData)
            else { return nil }
        guard let cgim = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * MemoryLayout<PixelData>.size,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return nil }
        self.init(cgImage: cgim)
    }
}

extension UIImage {
    func getPixelColor (x: Int, y: Int) -> UIColor? {
        guard x >= 0 && x < Int(size.width) && y >= 0 && y < Int(size.height),
            let cgImage = cgImage,
            let provider = cgImage.dataProvider,
            let providerData = provider.data,
            let data = CFDataGetBytePtr(providerData) else {
            return nil
        }

        let numberOfComponents = 4
        let pixelData = ((Int(size.width) * y) + x) * numberOfComponents

        let r = CGFloat(data[pixelData]) / 255.0
        let g = CGFloat(data[pixelData + 1]) / 255.0
        let b = CGFloat(data[pixelData + 2]) / 255.0
        let a = CGFloat(data[pixelData + 3]) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
}

public struct Pixel {
    public var value: UInt32
    
    public var red: UInt8 {
        get {
            return UInt8(value & 0xFF)
        } set {
            value = UInt32(newValue) | (value & 0xFFFFFF00)
        }
    }
    
    public var green: UInt8 {
        get {
            return UInt8((value >> 8) & 0xFF)
        } set {
            value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF)
        }
    }
    
    public var blue: UInt8 {
        get {
            return UInt8((value >> 16) & 0xFF)
        } set {
            value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF)
        }
    }
    
    public var alpha: UInt8 {
        get {
            return UInt8((value >> 24) & 0xFF)
        } set {
            value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF)
        }
    }
}
