//
//  YoloV4Classifier.swift
//  OptiScanBarcodeReader
//
//  Created by MAC-OBS-25 on 28/02/22.
//

import UIKit
import CoreImage
import Accelerate

public func DebugPrint(message: String, function: FUNTIONTYPE) {
    
    switch YoloV4Classifier.shared.isProduction() {
    case false:
        print("\(YoloV4Classifier.shared.getCurrentMillis()): \(function.rawValue): \(message)")
        
    default:
        break
    }
    
}

extension UIWindow {
    static var key: UIWindow? {
        if #available(iOS 13, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}


struct BoundingBox {
    var indexOne: Float
    var indexTwo: Float
    var indexThree: Float
    var indexFour: Float
}

struct OutScore {
    var indexOne: Float
    var indexTwo: Float
}

/// Stores results for a particular frame that was successfully run through the `Interpreter`.
struct Result {
    let inferences: [Inference]
}

/// Stores one formatted inference.
struct Inference {
    let confidence: Float
    let className: String
    let rect: CGRect
    let boundingRect:CGRect
    let displayColor: UIColor
    let outputImage : UIImage
    let previewWidth : CGFloat
    let previewHeight : CGFloat
}

/// Information about a model file or labels file.
typealias FileInfo = (name: String, extension: String)
typealias CompletionHandler = (_ success: Result?) -> Void

fileprivate let tensorModelName:String = "yolov4-tiny_final_28_03_22"
fileprivate let tensorModelExtension:String = "tflite"
fileprivate let tensorLabelDataName:String = "labelmap"
fileprivate let tensorLabelDataExt:String = "txt"


/// Information about theYoloV4 model.
enum YoloV4 {
    static let modelInfo: FileInfo = (name: tensorModelName, extension: tensorModelExtension)
    static let labelsInfo: FileInfo = (name: tensorLabelDataName, extension: tensorLabelDataExt)
}


/// This class handles all data preprocessing and makes calls to run inference on a given frame
/// by invoking the `Interpreter`. It then formats the inferences obtained and returns the top N
/// results for a successful inference.
public class YoloV4Classifier: NSObject {
    
    static public let shared = YoloV4Classifier()

    // MARK: - Internal Properties
    /// The current thread count used by the TensorFlow Lite Interpreter.
    ///
    private var threadCount: Int = 0
    
    private var originalBufferImage: UIImage?
    private var resizedBufferImage: UIImage?
    private let threshold: Double = 0.5

    private let batchSize = 1
    private let inputChannels = 3
    private let inputWidth = 416.0
    private let inputHeight = 416.0
    
    // image mean and std for floating model, should be consistent with parameters used in model training
    private let imageMean: Float = 127.5
    private let imageStd:  Float = 127.5
    private var labels: [String] = []
    
    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    private var interpreter: Interpreter?
    private var isProdVersion: Bool! = false
    private var scannerType: ScannerType?
    
    
    // MARK: - Initialization
    
    /// A failable initializer for `YoloV4Classifier`. A new instance is created if the model and
    /// labels files are successfully loaded from the app's main bundle. Default `threadCount` is 1.
    
    public func initializeModelInfo(selectedScannerType: ScannerType) {
        
        self.scannerType = selectedScannerType
        self.threadCount = 1
        
        let modelFilename = YoloV4.modelInfo.name
        let bundle = Bundle(for: type(of: self))
        guard let modelPath = bundle.path(forResource: modelFilename, ofType:  YoloV4.modelInfo.extension) else {
            DebugPrint(message: "Failed to load the model file with name: \(modelFilename).", function: .initializeModel)
            return
        }
        
        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter?.allocateTensors()
        } catch let error {
            DebugPrint(message: "Failed to create the interpreter with error: \(error.localizedDescription)", function: .initializeModel)
            return
        }
        
    }
        
    //MARK: - Save images in photos library
    
    @objc
    private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            DebugPrint(message: "\(error.localizedDescription)", function: .imageSavedYolo)
        } else {
            DebugPrint(message: "Your image has been saved to your photos.", function: .imageSavedYolo)
        }
    }
    
    //MARK: - Public methods

    //MARK: - Internal methods
    
    public func debugMode(enable: Bool) {
        self.isProdVersion = !enable
    }
    
    func isProduction() -> Bool {
        return isProdVersion
    }
    
    func getCurrentMillis() -> String {
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MMM-dd HH:mm:ss.SSSS"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        return dateString
    }
    
    //MARK: - Private methods
    
    func runModelNew(onFrame pixelBuffer: CVPixelBuffer,  previewSize: CGSize, completionHandler: CompletionHandler) {
        
        originalBufferImage = pixelBuffer.toImage()
        
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
               sourcePixelFormat == kCVPixelFormatType_32RGBA)
        
        DebugPrint(message: "Start Runmodel", function: .runModel)
        
        let imageChannels = 4
        assert(imageChannels >= inputChannels)
        
        resizedBufferImage = pixelBuffer.toImage()
        
        // Crops the image to the biggest square in the center and scales it down to model dimensions.
        
        DebugPrint(message: "BEFORE RESIZE", function: .runModel)
        
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return
        }
        
        DebugPrint(message: "AFTER RESIZE", function: .runModel)
        
        let outputBoundingBox: Tensor
        let outputClasses: Tensor
        
        do {
            
            DebugPrint(message: "MODEL STARTED", function: .runModel)

            let inputTensor = try interpreter?.input(at: 0)
            
            DebugPrint(message: "BEFORE RGB RESIZE", function: .runModel)
            
            // Remove the alpha component from the image buffer to get the RGB data.
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: batchSize * Int(inputWidth) * Int(inputHeight) * inputChannels,
                isModelQuantized: inputTensor?.dataType == .uInt8
            ) else {
                DebugPrint(message: "Failed to convert the image buffer to RGB data.", function: .runModel)
                return
            }
            
            DebugPrint(message: "AFTER RGB SIZE", function: .runModel)

            // Copy the RGB data to the input `Tensor`.
            try interpreter?.copy(rgbData, toInputAt: 0)
            
            // Run inference by invoking the `Interpreter`.
            try interpreter?.invoke()
            outputBoundingBox = try interpreter?.output(at: 0) as! Tensor
            outputClasses = try interpreter?.output(at: 1) as! Tensor
            
            DebugPrint(message: "After response", function: .runModel)

            
        } catch let error {
            DebugPrint(message: "Failed to invoke the interpreter with error: \(error.localizedDescription)", function: .runModel)
            return
        }
        
        let outputcount: Int = outputBoundingBox.shape.dimensions[1]
        let boundingBox = [BoundingBox](unsafeData: outputBoundingBox.data)!
        let OutScore = [OutScore](unsafeData: outputClasses.data)!
        
        let resultArray = formatResults(
            boundingBox: boundingBox,
            outputClasses: OutScore,
            outputCount: outputcount,
            width: CGFloat(imageWidth),
            height: CGFloat(imageHeight), previewSize: previewSize
        )
         
        let result = Result(inferences: resultArray)
        completionHandler(result)
 
    }
    
    /// This class handles all data preprocessing and makes calls to run inference on a given frame
    /// through the `Interpreter`. It then formats the inferences obtained and returns the top N
    /// results for a successful inference.
    ///
    func runModel(onFrame pixelBuffer: CVPixelBuffer, previewSize: CGSize) -> Result? {
        
        DebugPrint(message: "Start Runmodel", function: .runModel)
        
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let imageChannels = 4
        assert(imageChannels >= inputChannels)
        resizedBufferImage = pixelBuffer.toImage()
        
        DebugPrint(message: "BEFORE RESIZE", function: .runModel)
        
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return nil
        }
        DebugPrint(message: "AFTER RESIZE", function: .runModel)
        
        
        let outputBoundingBox: Tensor
        let outputClasses: Tensor
        do {
            
            DebugPrint(message: "MODEL STARTED", function: .runModel)
            let inputTensor = try interpreter?.input(at: 0)
            
            DebugPrint(message: "BEFORE RGB RESIZE", function: .runModel)
            // Remove the alpha component from the image buffer to get the RGB data.
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: batchSize * Int(inputWidth) * Int(inputHeight) * inputChannels,
                isModelQuantized: inputTensor?.dataType == .uInt8
            ) else {
                DebugPrint(message: "Failed to convert the image buffer to RGB data.", function: .runModel)
                return nil
            }
            
            
            DebugPrint(message: "AFTER RGB SIZE", function: .runModel)
            
            // Copy the RGB data to the input `Tensor`.
            try interpreter?.copy(rgbData, toInputAt: 0)
            // Run inference by invoking the `Interpreter`.
            try interpreter?.invoke()
            
            outputBoundingBox = try interpreter?.output(at: 0) as! Tensor
            outputClasses = try interpreter?.output(at: 1) as! Tensor
            DebugPrint(message: "MODEL COMPLETED", function: .runModel)
            
            
        } catch let error {
            DebugPrint(message: "Failed to invoke the interpreter with error: \(error.localizedDescription)", function: .runModel)
            return nil
        }
        
        let outputcount: Int = outputBoundingBox.shape.dimensions[1]
        
        let boundingBox = [BoundingBox](unsafeData: outputBoundingBox.data)!
        
        let OutScore = [OutScore](unsafeData: outputClasses.data)!
        
        // Formats the results
        DebugPrint(message: "BEFORE RESULT ARRAY", function: .runModel)
        
        let resultArray = formatResults(
            boundingBox: boundingBox,
            outputClasses: OutScore,
            outputCount: outputcount,
            width: CGFloat(imageWidth),
            height: CGFloat(imageHeight), previewSize: previewSize
        )
        
        DebugPrint(message: "AFTER RESULT ARRAY", function: .runModel)
        // Returns the inference time and inferences
        let result = Result(inferences: resultArray)
        return result
        
    }
    
    
    /// Filters out all the results with confidence score < threshold and returns the top N results
    /// sorted in descending order.
    func formatResults(boundingBox: [BoundingBox], outputClasses: [OutScore],
                       outputCount: Int, width: CGFloat,
                       height: CGFloat, previewSize: CGSize) -> [Inference] {
        
        DebugPrint(message: "PREVIEW SIZE: \n \(previewSize)", function: .formatResults)
        
        let modelConfidence:Float = 0.3
        var resultsArray: [Inference] = []
        if (outputCount == 0) {
            return resultsArray
        }

        DebugPrint(message: "BEFORE OUTPUT ARRAY", function: .formatResults)
        
        let maxOne = outputClasses.map { $0.indexOne }.max()
        let maxTwo = outputClasses.map { $0.indexTwo }.max()
        
        DebugPrint(message: "Max ARRAY One \(String(describing: maxOne))", function: .formatResults)
        DebugPrint(message: "Max ARRAY Two \(String(describing: maxTwo))", function: .formatResults)
        
        let indexOne = outputClasses.firstIndex(where: {$0.indexOne == maxOne})
        let indexTwo = outputClasses.firstIndex(where: {$0.indexTwo == maxTwo})
        
        DebugPrint(message: "Index One \(String(describing: indexOne))", function: .formatResults)
        DebugPrint(message: "Index Two \(String(describing: indexTwo))", function: .formatResults)
        DebugPrint(message: "After OUTPUT ARRAY", function: .formatResults)
        
        switch scannerType {
        case .qrcode:
            if maxOne! > modelConfidence {
                
                DebugPrint(message: "BEFORE Bounding calculation", function: .formatResults)

                let boundBoxAry = boundingBox[indexOne!]
                
                DebugPrint(message: "Bounding box: \(String(describing: boundBoxAry))", function: .formatResults)

                let boundingBoxRect = self.calculateBoundBoxRect(boundingBox: boundBoxAry, previewHeight: previewSize.height, previewWidth: previewSize.width)
                
                DebugPrint(message: "After bounding calculation:", function: .formatResults)

                let cropRect = self.calculateCropingRect(boundingBox: boundBoxAry)
                
                DebugPrint(message: "After cropping rect", function: .formatResults)

                let croppedBar = self.resizedBufferImage?.cropImage(frame: cropRect) ?? UIImage()
                
                DebugPrint(message: "After resized image", function: .formatResults)

                let inference = Inference(confidence: Float(threshold),
                                          className: "QR",
                                          rect: cropRect, boundingRect: boundingBoxRect,
                                          displayColor: UIColor.red, outputImage: croppedBar,previewWidth: width,previewHeight: height)
                resultsArray.append(inference)
                
            } else {
                
                DebugPrint(message: "Else QR Confidence level", function: .formatResults)
                //isProdVersion ? nil : UIImageWriteToSavedPhotosAlbum(originalBufferImage! , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
                
            }
            
        case .barcode:
            if maxTwo! > modelConfidence {
                
                let boundBoxAry = boundingBox[indexTwo!]
                DebugPrint(message: "Bounding box: \(String(describing: boundBoxAry))", function: .formatResults)

                let boundingBoxRect = self.calculateBoundBoxRect(boundingBox: boundBoxAry, previewHeight: previewSize.height, previewWidth: previewSize.width)
                let cropRect = self.calculateCropingRect(boundingBox: boundBoxAry)
                let croppedBar = self.resizedBufferImage?.cropImage(frame: cropRect) ?? UIImage()
                let inference = Inference(confidence: Float(threshold),
                                          className: "BAR",
                                          rect: cropRect, boundingRect: boundingBoxRect,
                                          displayColor: UIColor.green, outputImage: croppedBar,previewWidth: width,previewHeight: height)
                resultsArray.append(inference)
                
            } else {
                
                DebugPrint(message: "Else BAR Code Confidence level", function: .formatResults)
                //isProdVersion ? nil : UIImageWriteToSavedPhotosAlbum(originalBufferImage! , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

            }
            
        case .any:
            let one = maxOne!
            let two = maxTwo!
            
            if(one >= modelConfidence || two >= modelConfidence) {
                
                if(one > two){
                    
                    let boundBoxAry = boundingBox[indexOne!]
                    DebugPrint(message: "Bounding box: \(String(describing: boundBoxAry))", function: .formatResults)
                    let boundingBoxRect = self.calculateBoundBoxRect(boundingBox: boundBoxAry, previewHeight: previewSize.height, previewWidth: previewSize.width)
                    let cropRect = self.calculateCropingRect(boundingBox: boundBoxAry)
                    let croppedBar = self.resizedBufferImage?.cropImage(frame: cropRect) ?? UIImage()
                    let inference = Inference(confidence: Float(threshold),
                                              className: "QR",
                                              rect: cropRect, boundingRect: boundingBoxRect,
                                              displayColor: UIColor.red, outputImage: croppedBar,previewWidth: width,previewHeight: height)
                    resultsArray.append(inference)
                    
                } else {
                    
                    let boundBoxAry = boundingBox[indexTwo!]
                    DebugPrint(message: "Bounding box: \(String(describing: boundBoxAry))", function: .formatResults)
                    let boundingBoxRect = self.calculateBoundBoxRect(boundingBox: boundBoxAry, previewHeight: previewSize.height, previewWidth: previewSize.width)
                    let cropRect = self.calculateCropingRect(boundingBox: boundBoxAry)
                    let croppedBar = self.resizedBufferImage?.cropImage(frame: cropRect) ?? UIImage()
                    let inference = Inference(confidence: Float(threshold),
                                              className: "BAR",
                                              rect: cropRect, boundingRect: boundingBoxRect,
                                              displayColor: UIColor.green, outputImage: croppedBar,previewWidth: width,previewHeight: height)
                    resultsArray.append(inference)
                    
                }
                
            } else {
                
                DebugPrint(message: "Else ANY Code Confidence level", function: .formatResults)
                //isProdVersion ? nil : UIImageWriteToSavedPhotosAlbum(originalBufferImage! , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

            }
            
        default:
            break
        }
        
        return resultsArray
        
    }
    
    private func calculateOriginalCropRect(index:Int, height:CGFloat, width:CGFloat, boundingBox:[Float]) -> CGRect {
        
        DebugPrint(message: "BUFFER SIZE \(width) \(height)", function: .originalCropRect)
        DebugPrint(message: "IPHONE SIZE \(UIScreen.main.bounds.size.width) \(UIScreen.main.bounds.size.height)", function: .originalCropRect)
        DebugPrint(message: "DIVIDED INDEX \(index)", function: .originalCropRect)
        
        var rect: CGRect = CGRect.zero
        rect.origin.y = CGFloat(boundingBox[4*index+1])
        rect.origin.x = CGFloat(boundingBox[4*index])
        rect.size.width = CGFloat(boundingBox[4*index+2])
        rect.size.height = CGFloat(boundingBox[4*index+3])
        DebugPrint(message: "416 MODEL OUTPUT RECT \(rect)", function: .originalCropRect)
        
        let ratioHeight = height / CGFloat(self.inputWidth)
        let ratioWidth = width / CGFloat(self.inputWidth)
        let x1 = CGFloat(rect.origin.x - rect.size.width / 2)
        let y1 =  CGFloat(rect.origin.y - rect.size.height / 2)
        let x2 = CGFloat(rect.origin.x + rect.size.width / 2)
        let y2 = CGFloat(rect.origin.y + rect.size.height / 2)
        
        let rec = CGRect(
            x: CGFloat(min(x1, x2)),
            y: CGFloat(min(y1, y2)),
            width: CGFloat(abs(x1 - x2)),
            height: CGFloat(abs(y1 - y2)))
        
        
        let finalRect = CGRect(x: (rec.origin.x * ratioWidth) , y: (rec.origin.y * ratioHeight) , width: (rec.size.width * ratioWidth)  , height: (rec.size.height * ratioHeight) )
        
        
        DebugPrint(message: "1920x1080 RECT FRAME \(finalRect)", function: .originalCropRect)
        
        return finalRect
        
    }
    
    private func calculateCropingRect(boundingBox: BoundingBox) -> CGRect{
        
        var rect: CGRect = CGRect.zero
        rect.origin.x = CGFloat(boundingBox.indexOne)
        rect.origin.y = CGFloat(boundingBox.indexTwo)
        rect.size.width = CGFloat(boundingBox.indexThree)
        rect.size.height = CGFloat(boundingBox.indexFour)
        
        let x = rect.origin.x/inputWidth
        let y = rect.origin.y/inputHeight
        let w = rect.size.width/inputWidth
        let h = rect.size.height/inputHeight
        
        let img = resizedBufferImage
        
        let image_h = img?.size.height ?? 0.0
        let image_w = img?.size.width ?? 0.0
        
        let orig_x       = x * image_w
        let orig_y       = y * image_h
        let orig_width   = w * image_w
        let orig_height  = h * image_h
        
        let x1 = orig_x + orig_width / 2
        let y1 = orig_y + orig_height / 2
        let x2 = orig_x - orig_width / 2
        let y2 = orig_y - orig_height / 2
        
        DebugPrint(message: "Rect X1:\(x1)  Y1: \(y1)", function: .originalCropRect)
        DebugPrint(message: "Rect X2:\(x2)  Y2: \(y2)", function: .originalCropRect)
        
        //        let finalRect = CGRect(x: (rec.origin.x * ratioWidth) - 25 , y: (rec.origin.y * ratioHeight) - 25, width: (rec.size.width * ratioWidth) + 50  , height: (rec.size.height * ratioHeight) + 50)
        
        
        var xMinValue = CGFloat(min(x1, x2))
        var yMinValue = CGFloat(min(y1, y2))
        
        if xMinValue > 25{
            xMinValue = xMinValue - 25
        }
        
        if yMinValue > 25{
            yMinValue = yMinValue - 25
        }
        
        let finalRect = CGRect(
            x: xMinValue,
            y: yMinValue,
            width: CGFloat(abs(x1 - x2)) + 50,
            height: CGFloat(abs(y1 - y2)) + 50)
        
        return finalRect
        
    }
    
    private func calculateBoundBoxRect(boundingBox: BoundingBox, previewHeight: CGFloat, previewWidth: CGFloat) -> CGRect {
        
        var rect: CGRect = CGRect.zero
        rect.origin.x = CGFloat(boundingBox.indexOne)
        rect.origin.y = CGFloat(boundingBox.indexTwo)
        rect.size.width = CGFloat(boundingBox.indexThree)
        rect.size.height = CGFloat(boundingBox.indexFour)
        
        let x = rect.origin.x/inputWidth
        let y = rect.origin.y/inputHeight
        let w = rect.size.width/inputWidth
        let h = rect.size.height/inputHeight
        
        //        let img = resizedBufferImage
        
        let image_h = previewHeight ?? 0.0
        let image_w = previewWidth ?? 0.0
        
        let orig_x       = x * image_w
        let orig_y       = y * image_h
        let orig_width   = w * image_w
        let orig_height  = h * image_h
        
        let x1 = orig_x + orig_width / 2
        let y1 = orig_y + orig_height / 2
        let x2 = orig_x - orig_width / 2
        let y2 = orig_y - orig_height / 2
        
        DebugPrint(message: "Rect X1:\(x1)  Y1: \(y1)", function: .calculateBoundBox)
        DebugPrint(message: "Rect X2:\(x2)  Y2: \(y2)", function: .calculateBoundBox)
        
        let finalRec = CGRect(
            x: CGFloat(min(x1, x2)),
            y: CGFloat(min(y1, y2)),
            width: CGFloat(abs(x1 - x2)),
            height: CGFloat(abs(y1 - y2)))
        
        return finalRec
        
    }
    
    private func calculateBoundingBoxRect(index:Int, previewHeight: CGFloat, previewWidth: CGFloat, boundingBox: [Float]) -> CGRect {
        
        var rect: CGRect = CGRect.zero
        rect.origin.y = CGFloat(boundingBox[4*index+1])
        rect.origin.x = CGFloat(boundingBox[4*index])
        rect.size.width = CGFloat(boundingBox[4*index+2])
        rect.size.height = CGFloat(boundingBox[4*index+3])
        
        let rec = CGRect(x: CGFloat(rect.origin.x - rect.size.width/2), y: CGFloat(rect.origin.y - rect.size.height/2),
                         width: CGFloat(rect.size.width), height: CGFloat(rect.size.height))
        
        let ratioHeight = previewHeight / CGFloat(self.inputWidth)
        let ratioWidth = previewWidth / CGFloat(self.inputWidth)
        //          let ynew = (896.0 * y1) / 416.0
        let finalRect = CGRect(x: rec.origin.x * ratioWidth , y:rec.origin.y * ratioHeight, width: rec.size.width * ratioWidth , height: rec.size.height * ratioHeight )
        return finalRect
        
    }
    
    /// Loads the labels from the labels file and stores them in the `labels` property.
    private func loadLabels(fileInfo: FileInfo) {
        let filename = fileInfo.name
        let fileExtension = fileInfo.extension
        let bundle = Bundle(for: type(of: self))
        
        guard let fileURL = bundle.url(forResource: filename, withExtension: fileExtension) else {
            fatalError("Labels file not found in bundle. Please add a labels file with name " +
                       "\(filename).\(fileExtension) and try again.")
        }
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            labels = contents.components(separatedBy: .newlines)
        } catch {
            fatalError("Labels file named \(filename).\(fileExtension) cannot be read. Please add a " +
                       "valid labels file and try again.")
        }
    }
    
    /// Returns the RGB data representation of the given image buffer with the specified `byteCount`.
    ///
    /// - Parameters
    ///   - buffer: The BGRA pixel buffer to convert to RGB data.
    ///   - byteCount: The expected byte count for the RGB data calculated using the values that the
    ///       model was trained on: `batchSize * imageWidth * imageHeight * componentsCount`.
    ///   - isModelQuantized: Whether the model is quantized (i.e. fixed point values rather than
    ///       floating point values).
    /// - Returns: The RGB data representation of the image buffer or `nil` if the buffer could not be
    ///     converted.
    
    private func rgbDataFromBuffer(
        _ buffer: CVPixelBuffer,
        byteCount: Int,
        isModelQuantized: Bool
    ) -> Data? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let destinationChannelCount = 3
        let destinationBytesPerRow = destinationChannelCount * width
        
        var sourceBuffer = vImage_Buffer(data: sourceData,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: sourceBytesPerRow)
        
        guard let destinationData = malloc(height * destinationBytesPerRow) else {
            DebugPrint(message: "Error: out of memory", function: .rgbDataFromBuffer)
            return nil
        }
        
        defer {
            free(destinationData)
        }
        
        var destinationBuffer = vImage_Buffer(data: destinationData,
                                              height: vImagePixelCount(height),
                                              width: vImagePixelCount(width),
                                              rowBytes: destinationBytesPerRow)
        
        if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA){
            vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        } else if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32ARGB) {
            vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        }
        
        let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
        if isModelQuantized {
            return byteData
        }
        
        // Not quantized, convert to floats
        let bytes = Array<UInt8>(unsafeData: byteData)!
        var floats = [Float]()
        for i in 0..<bytes.count {
            floats.append((Float(bytes[i]) - imageMean) / imageStd)
        }
        return Data(copyingBufferOf: floats)
    }
        
}
