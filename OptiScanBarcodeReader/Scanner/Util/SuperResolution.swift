//
//  SuperResolution.swift
//  OptiScanBarcodeReader
//
//  Created by MAC-OBS-25 on 31/03/22.
//


/// Information about a model file or labels file.
typealias SRFileInfo = (name: String, extension: String)


fileprivate let tensorModelName:String = "Sensifai_SuperResolution_TFLite"
fileprivate let tensorModelExtension:String = "tflite"


/// Information about theYoloV4 model.
enum SRInfo {
  static let modelInfo: SRFileInfo = (name: tensorModelName, extension: tensorModelExtension)
}

import UIKit
import CoreImage
import Accelerate
import opencv2
import TensorFlowLiteC
import CoreML


class SuperResolution: NSObject {
    
    
    private var interpreter: Interpreter?
    private var results:[Float] = []
    private let inputWidth = 512
    private let inputHeight = 512
    
    static let shared = SuperResolution()

    func convertImgToSRImg(inputImage:UIImage) -> UIImage?{
        
        var srcImgWidth:CGFloat?// = 0.0
        var srcImgHeight:CGFloat?// = 0.0
        
        let bundle = Bundle(for: type(of: self))
        guard let modelPath = bundle.path(forResource: SRInfo.modelInfo.name, ofType:   SRInfo.modelInfo.extension) else {
            print("Failed to load the model file with name: \(SRInfo.modelInfo.name).")
            return nil
        }
        let outputTensor: Tensor?
        
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            
            guard let imagePath = bundle.path(forResource: "srImg", ofType: "png") else {
                print("Failed to load the model file with name:")
                return nil
            }
            print("IMAGE PATH",imagePath)
            let imageOld = inputImage//UIImage(contentsOfFile: imagePath)
            
            srcImgWidth = imageOld.size.width
            srcImgHeight = imageOld.size.height
            
            let src = Mat(uiImage: imageOld)
            
            let dst = Mat()
            //
            Imgproc.resize(src: src, dst: dst, dsize: Size2i(width: 512, height: 512))
            
            let imgDst = dst.toUIImage()
            
            
            let image: CGImage = dst.toCGImage()// Your input image
            guard let context = CGContext(
                data: nil,
                width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            ) else {
                return nil
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            
            guard let imageData = context.data else { return nil }
            
            var inputData = Data()
            for row in 0 ..< 512 {
                for col in 0 ..< 512 {
                    let offset = 4 * (row * context.width + col)
                    // (Ignore offset 0, the unused alpha channel)
                    let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
                    let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
                    let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)
                    
                    // Normalize channel values to [0.0, 1.0]. This requirement varies
                    // by model. For example, some models might require values to be
                    // normalized to the range [-1.0, 1.0] instead, and others might
                    // require fixed-point values or the original bytes.
                    //        let scaledFloats = scaledBytes.map { (Float32($0) - 127.5) / 1.0 }
                    
                    var normalizedRed = (Float32(red) - 127.5) / 1.0
                    var normalizedGreen = (Float32(green) - 127.5) / 1.0
                    var normalizedBlue = (Float32(blue) - 127.5) / 1.0
                    
                    // Append normalized values to Data object in RGB order.
                    let elementSize = MemoryLayout.size(ofValue: normalizedRed)
                    var bytes = [UInt8](repeating: 0, count: elementSize)
                    memcpy(&bytes, &normalizedRed, elementSize)
                    inputData.append(&bytes, count: elementSize)
                    memcpy(&bytes, &normalizedGreen, elementSize)
                    inputData.append(&bytes, count: elementSize)
                    memcpy(&bytes, &normalizedBlue, elementSize)
                    inputData.append(&bytes, count: elementSize)
                }
            }
            
            
            try interpreter?.allocateTensors()
            do{
                try interpreter?.copy(inputData, toInputAt: 0)
                
            }catch let error{
                print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
                
            }
            try interpreter?.invoke()
            
            // Get the output `Tensor` to process the inference results.
            outputTensor = try interpreter?.output(at: 0)
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        
        //        output = [Float32](unsafeData: outputTensor?.data ?? Data()) ?? []
        //        let formattedArray = outputTensor?.shape.dimensions ?? []
        let output: [Float32]
        
        output = [Float32](unsafeData: outputTensor?.data ?? Data()) ?? []
        //        let formattedArray = outputTensor?.shape.dimensions ?? []
        
        let boundingBox = [SuperResolutionModel](unsafeData: outputTensor!.data)!
        
        let imageWidth = 512
        let imageHeight = 512
        let imageSize = imageWidth * imageHeight
        
        
        guard let min_value = output.min() else { return nil}
        guard let max_value = output.max() else { return nil}
        
        print("min_value \(min_value) max_vale \(max_value)")
        
        let pixelsOutput = self.intervalMapping(outputArray: output, from_min: min_value, from_max: max_value, to_min: 0, to_max: 255.0)
        
        var pixels = [PixelData]()
        for i in stride(from: 0, to:imageSize * 3 , by: 3) {

            let pixelValue = PixelData(a: 255, r: UInt8(pixelsOutput[i]), g: UInt8(pixelsOutput[i+1]), b: UInt8(pixelsOutput[i+2]))
            
            
            pixels.append(pixelValue)
        }
        
        let srcImg2xSize = CGSize(width: srcImgWidth!, height: srcImgHeight!)
        
        let whiteImage = UIImage.from(color: .white)
        var finalSRImg = whiteImage.imageFromARGB32Bitmap(pixels: pixels, width: imageWidth, height: imageHeight)
        
        let src = Mat(uiImage: finalSRImg)
        
        let dst = Mat()
        //
        Imgproc.resize(src: src, dst: dst, dsize: Size2i(width: Int32(srcImgWidth!) * 2, height: Int32(srcImgHeight!) * 2))

        
        let imgSRreSize = dst.toUIImage()//self.resizeImage(image: finalSRImg, targetSize: srcImg2xSize)
        
        finalSRImg = self.applyGammaCorrection(to: imgSRreSize)!
        
        print(finalSRImg)
        return finalSRImg
        
    }
    
    func intervalMapping(outputArray:[Float],from_min:Float,from_max:Float, to_min:Float, to_max:Float) -> [Float]{
        var resultArray:[Float] = []
        let from_range:Float = from_max - from_min
        let to_range = to_max - to_min
        for i in 0..<outputArray.count {
            let val:Float = outputArray[i]
            let elementUpdate = NSNumber(value: (((val - from_min) / from_range) * to_range) + to_min).floatValue
            resultArray.append(elementUpdate)
        }
        return resultArray
    }
    
   
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
       let size = image.size
       
       let widthRatio  = targetSize.width  / size.width
       let heightRatio = targetSize.height / size.height
       
       // Figure out what our orientation is, and use that to form the rectangle
       var newSize: CGSize
       if(widthRatio > heightRatio) {
           newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
       } else {
           newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
       }
       
       // This is the rect that we've calculated out and this is what is actually used below
       let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
       
       // Actually do the resizing to the rect using the ImageContext stuff
       UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
       image.draw(in: rect)
       let newImage = UIGraphicsGetImageFromCurrentImageContext()
       UIGraphicsEndImageContext()
       
       return newImage!
   }
    
    func applyGammaCorrection(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Redraw image for correct pixel format
        var colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        var bytesPerRow = width * 4
        
        let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
        
        guard let imageContext = CGContext(
            data: imageData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        imageContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
        
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
            
            gammaR.append(min(MAX_VALUE_INT, Int((MAX_VALUE_DBL * pow(Double(i) / MAX_VALUE_DBL, REVERSE/0.6) + 0.5))))
            
            gammaG.append(min(MAX_VALUE_INT, Int((MAX_VALUE_DBL * pow(Double(i) / MAX_VALUE_DBL, REVERSE/0.6) + 0.5))))
            
            gammaB.append(min(MAX_VALUE_INT, Int((MAX_VALUE_DBL * pow(Double(i) / MAX_VALUE_DBL, REVERSE/0.6) + 0.5))))
            
        }
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                var pixel = pixels[index]
                
                let redPixel = Int(pixel.red)
                let greenPixel = Int(pixel.green)
                let bluePixel = Int(pixel.blue)
                let alphaPixel = Int(pixel.alpha)
                
                pixel.alpha = UInt8(alphaPixel)
                pixel.red = UInt8(gammaR[redPixel])
                pixel.blue = UInt8(gammaB[bluePixel])
                pixel.green = UInt8(gammaG[greenPixel])

                pixels[index] = pixel
            }
        }
        
        colorSpace = CGColorSpaceCreateDeviceRGB()
        bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        bytesPerRow = width * 4
        
        guard let context = CGContext(
            data: pixels.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            releaseCallback: nil,
            releaseInfo: nil
        ) else { return nil }
        
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
    }
}

public struct PixelData {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

public extension UIImage{
    static func from(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(color.cgColor)
        context!.fill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
    
    func imageFromARGB32Bitmap(pixels:[PixelData], width: Int, height: Int)->UIImage {
       let bitsPerComponent:Int = 8
       let bitsPerPixel:Int = 32
       
//        assert(pixels.count == Int(width * height) * 3)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)

       var data = pixels // Copy to mutable []
       guard
           let providerRef = CGDataProvider(
               data: Data(bytes: &data, count: data.count * MemoryLayout<PixelData>.size) as CFData
           )
       else { fatalError("fail in image convert") }
       
       guard
           let cgim = CGImage(
               width: width,
               height: height,
               bitsPerComponent: bitsPerComponent,
               bitsPerPixel: bitsPerPixel,
               bytesPerRow: width * MemoryLayout<PixelData>.size,
               space: rgbColorSpace,
               bitmapInfo: bitmapInfo,
               provider: providerRef,
               decode: nil,
               shouldInterpolate: true,
               intent: CGColorRenderingIntent.defaultIntent
           )
       else { fatalError("fail in image convert 2")}
       return UIImage(cgImage: cgim)
    }
    
    
}


struct SuperResolutionModel {
    var r: Float
    var g: Float
    var b: Float
}

extension UIImage {
    var data : Data? {
      return cgImage?.dataProvider?.data as Data?
    }
}
