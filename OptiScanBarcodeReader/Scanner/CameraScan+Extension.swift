//
//  CameraScan+Extension.swift
//  OptiScanBarcodeReader
//
//  Created by MAC-OBS-25 on 01/03/22.
//

import UIKit
import Foundation
import AVFoundation
import opencv2
import Vision
import AudioToolbox

extension CameraScan: UINavigationControllerDelegate {
    
   private var hintsZxing:ZXDecodeHints {
        let formats = ZXDecodeHints()
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 1))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 2))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 3))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 4))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 5))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 6))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 7))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 8))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 9))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 10))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 11))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 12))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 13))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 14))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 15))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 16))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 17))
        return formats
    }
    
    /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
     */
    func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
        // Run the live camera pixelBuffer through tensorFlow to get the result
        //        let pixImage = pixelBuffer.toImage()
        //        let fixOrient = self.fixOrientation(img: pixImage)
        
        result = YoloV4Classifier.shared.runModel(onFrame: pixelBuffer,previewSize: self.previewSize)
//        result = YoloV4Classifier.shared.runModelNew(onFrame: pixelBuffer,previewSize: self.previewSize)
        //        let src = Mat(uiImage: UIImage(named: "long_distance.jpg")!)
        ////
        //        let dst = Mat()
        //        opencv2.Core.normalize(src: src, dst: dst, alpha: 1.0, beta: 127.5, norm_type: NormTypes.NORM_INF)
        guard let displayResult = result else {
            return
        }
   
        for inference in displayResult.inferences {
            self.processResult(cropImage: inference.outputImage,previewWidth: inference.previewWidth,previewHeight: inference.previewHeight, inference: inference)
        }
        
        //      let width = CVPixelBufferGetWidth(pixelBuffer)
        //      let height = CVPixelBufferGetHeight(pixelBuffer)
        
        DispatchQueue.main.async {
            print("BEFORE DRAW: \(self.getCurrentMillis())")
            
            // Draws the bounding boxes and displays class names and confidence scores.
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: 0.0, height: 0.0))
            print("AFTER DRAW: \(self.getCurrentMillis())")
        }
    }
    
    internal func processResult(cropImage:UIImage,previewWidth:CGFloat,previewHeight:CGFloat,inference:Inference){
//        print("###### processResult")
//        print("AFTER performRotate: \(getCurrentMillis())")
        if inference.className == "QR" {
//            print("BEFORE QR DECODE: \(getCurrentMillis())")
            
//            print("CROPPED IMAGE SIZE",cropImage.size)
            var resultImage = UIImage()
            if isQrLongDistance(image: cropImage,previewWidth: previewWidth,previewHeight: previewHeight) {
//                print("QR Long Distance")
                resultImage = cropImage.upscaleQRcode()
                
                resultImage = SuperResolution.shared.convertImgToSRImg(inputImage: resultImage) ?? UIImage()
//                print("UPSCALE RESIZE",resultImage.size)
            } else {
                resultImage = cropImage
            }

            let points = NSMutableArray()
            let mat = Mat.init(uiImage: resultImage)
            let result = WeChatQRCode().detectAndDecode(img: mat, points: points)
            print("WECHAT RESULT",result)
            
            if result.first == nil || result.first == "" {
                self.decodeZxing(image: resultImage)
            } else {
//                print("###### FOUND QR",result.first ?? "")
//                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                found(code: result.first ?? "")
            }
//            print("AFTER QR DECODE: \(getCurrentMillis())")
//            print("AFTER ROTATE: \(getCurrentMillis())")
        } else {
            
            let resultImage:UIImage?
//            UIImageWriteToSavedPhotosAlbum(cropImage , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            if isBarcodeLongDistance(image: cropImage,previewWidth: previewWidth,previewHeight: previewHeight) {
               print("BAR Long Distance")
                resultImage = cropImage.upscaleBarcode()
                //print("UPSCALE RESIZE",resultImage?.size)
            } else {
                resultImage = cropImage
            }


           // DispatchQueue.main.async {
           //     self.previewImage.image = cropImage
           // }
            let rotatedImage = self.processImage(image: resultImage ?? UIImage())
            self.decodeZxing(image: rotatedImage)
            
        }
        
        startCamera()
    }
    
//    //MARK: - Add image to Library
//       @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
//           if let error = error {
//               // we got back an error!
//               print(error.localizedDescription)
//           } else {
//               print("Your image has been saved to your photos.")
//           }
//       }
    
    
   internal func decodeZxing(image:UIImage){
    
        let source: ZXLuminanceSource = ZXCGImageLuminanceSource(cgImage: image.cgImage)
        let binazer = ZXHybridBinarizer(source: source)
        let bitmap = ZXBinaryBitmap(binarizer: binazer)
//        print("###### BITMAP IMAGE WIDTH \(bitmap?.width ?? 0)")

        let reader = ZXMultiFormatReader()
        let hints = hintsZxing
       
        //print("###### DECODE BITMAP",try? reader.decode(bitmap, hints: hints))
       
        if let result = try? reader.decode(bitmap, hints: hints) {
            barDecodeCount = barDecodeCount + 1
//            print("$$$ $$$ $$ $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ $$$$$$$$$$$$$$ BAR DECODED RESULT COUNT",barDecodeCount)
//            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: result.text ?? "")
        } else {
            print("###### DECODE BITMAP Nil")
           // UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

        }

    }
    
    private func fixOrientation(img: UIImage) -> UIImage {
        
        if ( img.imageOrientation == UIImage.Orientation.up ) {
            return img;
        }
        
        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        if ( img.imageOrientation == UIImage.Orientation.down || img.imageOrientation == UIImage.Orientation.downMirrored ) {
            transform = transform.translatedBy(x: img.size.width, y: img.size.height)
            transform = transform.rotated(by: CGFloat(Double.pi))
        }
        
        if ( img.imageOrientation == UIImage.Orientation.left || img.imageOrientation == UIImage.Orientation.leftMirrored ) {
            transform = transform.translatedBy(x: img.size.width, y: 0)
            transform = transform.rotated(by: CGFloat(Double.pi / 2.0))
        }
        
        if ( img.imageOrientation == UIImage.Orientation.right || img.imageOrientation == UIImage.Orientation.rightMirrored ) {
            transform = transform.translatedBy(x: 0, y: img.size.height);
            transform = transform.rotated(by: CGFloat(-Double.pi / 2.0));
        }
        
        if ( img.imageOrientation == UIImage.Orientation.upMirrored || img.imageOrientation == UIImage.Orientation.downMirrored ) {
            transform = transform.translatedBy(x: img.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        if ( img.imageOrientation == UIImage.Orientation.leftMirrored || img.imageOrientation == UIImage.Orientation.rightMirrored ) {
            transform = transform.translatedBy(x: img.size.height, y: 0);
            transform = transform.scaledBy(x: -1, y: 1);
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        let ctx: CGContext = CGContext(data: nil, width: Int(img.size.width), height: Int(img.size.height),
                                       bitsPerComponent: img.cgImage!.bitsPerComponent, bytesPerRow: 0,
                                       space: img.cgImage!.colorSpace!,
                                       bitmapInfo: img.cgImage!.bitmapInfo.rawValue)!;
        
        ctx.concatenate(transform)
        
        if ( img.imageOrientation == UIImage.Orientation.left ||
             img.imageOrientation == UIImage.Orientation.leftMirrored ||
             img.imageOrientation == UIImage.Orientation.right ||
             img.imageOrientation == UIImage.Orientation.rightMirrored ) {
            ctx.draw(img.cgImage!, in: CGRect(x: 0,y: 0,width: img.size.height,height: img.size.width))
        } else {
            ctx.draw(img.cgImage!, in: CGRect(x: 0,y: 0,width: img.size.width,height: img.size.height))
        }
        
        // And now we just create a new UIImage from the drawing context and return it
        return UIImage(cgImage: ctx.makeImage()!)
    }
    
    private func isQrLongDistance(image:UIImage,previewWidth:CGFloat,previewHeight:CGFloat) ->Bool{
        let isLong = LongDistance().isLongDistanceQRImage(cropImageWidth: image.size.width, cropImageHeight: image.size.height, previewWidth: previewWidth, previewHeight: previewHeight)
        return isLong
    }
    
   private func isBarcodeLongDistance(image:UIImage,previewWidth:CGFloat,previewHeight:CGFloat) ->Bool{
        let isLong = LongDistance().isLongDistanceBarcodeImage(cropImageWidth: image.size.width, cropImageHeight: image.size.height, previewWidth: previewWidth, previewHeight: previewHeight)
        return isLong
    }
    
    /**
     This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
     */
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {

        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()
        
      let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)

      guard !inferences.isEmpty else {
        return
      }

      var objectOverlays: [ObjectOverlay] = []

      for inference in inferences {

        // Translates bounding box rect to current view.
          var convertedRect = inference.rect
//          print("overlayView width",self.overlayView.bounds.size.width)
//          print("overlayView height",self.overlayView.bounds.size.height)
//          print("inference.rect",inference.rect)

        if convertedRect.origin.x < 0 {
            convertedRect.origin.x = self.edgeOffset
        }

        if convertedRect.origin.y < 0 {
          convertedRect.origin.y = self.edgeOffset
        }

          if convertedRect.maxY > self.overlayView.bounds.maxY {
              convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
          }

          if convertedRect.maxX > self.overlayView.bounds.maxX {
              convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
        }

        let confidenceValue = Int(inference.confidence * 100.0)
        let string = "\(inference.className)  (\(confidenceValue)%)"

        let size = string.size(usingFont: displayFont)
          print("Converted Rect",convertedRect)

          let objectOverlay = ObjectOverlay(name: string, borderRect: inference.boundingRect, nameStringSize: size, color: inference.displayColor, font: displayFont)
          print("BOUNDING Rect",inference.boundingRect)

        objectOverlays.append(objectOverlay)
      }

      // Hands off drawing to the OverlayView
      self.draw(objectOverlays: objectOverlays)

    }
    
    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    func draw(objectOverlays: [ObjectOverlay]) {
//        print("&&&&&& &&&&&&& &&&&&&& OBJECT OVERLAY",objectOverlays)
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.setNeedsDisplay()
    }
    
    
}
 

private func getValidBarCode(_ codeFormat: Int) -> String {
    let codes = ["Aztec", "CODABAR", "Code 39", "Code 93", "Code 128", "Data Matrix", "EAN-8", "EAN-13", "ITF", "MaxiCode", "PDF417", "QR Code", "RSS 14", "RSS EXPANDED", "UPC-A", "UPC-E", "UPC/EAN"]
    if codeFormat < codes.count {
        return codes[codeFormat]
    } else {
        return "QR Code"
    }
}

/**
 This class manages all camera related functionality
 */
public class CameraFeedManager: NSObject {
    
    // MARK: Camera Related Instance Variables
    
    private var lastZoomFactor: CGFloat = 1.0
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 1.0
    private var captureDevice: AVCaptureDeviceInput?
    
    private var originalBufferImage: UIImage?

    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private weak var outterWhiteRectView: UIView!
    private weak var blinkLabel: UILabel!
    private weak var expireLabel: UILabel!
    
    private let previewView: PreviewView
    private var islicenceExpired: Bool = false
    
    let sessionQueue = DispatchQueue(label: "sessionQueue")
    let session: AVCaptureSession = AVCaptureSession()
    let edgeOffset: CGFloat = 2.0
    var overlayView = OverlayView()
    var frameCount: Int = 0
    var previewSize: CGSize?
    
    var isSessionRunning = false
    var cameraConfiguration: CameraConfiguration = .failed
    
    public var maskSize: CGSize = CGSize(width: 300, height: 300)
    public var cornerLength: CGFloat = 10
    public var lineWidth: CGFloat = 7
    public var lineColor: UIColor = .white
    public var lineCap: CAShapeLayerLineCap = .round
    
    private var maskContainer: CGRect {
        CGRect(x: (((self.previewView.bounds.size.width - maskSize.width) - 24) / 2),
               y: (((self.previewView.bounds.size.height - maskSize.height) - 0) / 2),
               width: maskSize.width, height: maskSize.height)
    }
    
    // MARK: CameraFeedManagerDelegate
    
    public weak var delegate: CameraFeedManagerDelegate?
    
    // MARK: Initializer
    
    public init(previewView: UIView, installedDate: Date) {
        
        self.previewView = PreviewView(frame: previewView.bounds)
        previewView.addSubview(self.previewView)
        
        super.init()
        
        // Initializes the session
        session.sessionPreset = .high
        self.previewView.session = session
        self.previewView.previewLayer.connection?.videoOrientation = .portrait
        self.previewView.previewLayer.videoGravity = .resizeAspectFill
        
        self.previewSize = self.previewView.bounds.size
        
        overlayView.frame = self.previewView.bounds
        overlayView.backgroundColor = UIColor.clear
        overlayView.clipsToBounds = true
        let outterWhiteRectViewItem = createOverlay()
        self.outterWhiteRectView = outterWhiteRectViewItem
        
        self.previewView.addSubview(overlayView)
        self.previewView.addSubview(self.outterWhiteRectView)
        self.previewView.bringSubviewToFront(overlayView)
        self.previewView.bringSubviewToFront(self.outterWhiteRectView)
        
        self.setupBlinkLabel(installedDate)
        self.setupPinchGesture()
        self.attemptToConfigureSession()
        setInitialZoom()
        
    }
    
    
    
    //    private var maskContainer: CGRect {
    //        CGRect(x: (self.previewView.bounds.width / 2) - (maskSize.width / 2),
    //               y: (self.previewView.bounds.height / 2) - (maskSize.height),
    //        width: maskSize.width, height: maskSize.height)
    //    }
    
    
    private func getValidBarCode(_ codeFormat: Int) -> String {
        
        let codes = ["Aztec", "CODABAR", "Code 39", "Code 93", "Code 128",
                     "Data Matrix", "EAN-8", "EAN-13", "ITF", "MaxiCode",
                     "PDF417", "QR Code", "RSS 14", "RSS EXPANDED", "UPC-A",
                     "UPC-E", "UPC/EAN"]
        
        if codeFormat < codes.count {
            return codes[codeFormat]
        } else {
            return "QR Code"
        }
        
    }
    
    private func minMaxZoom(_ factor: CGFloat, device:AVCaptureDevice) -> CGFloat {
        return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
    }
    
    private func setInitialZoom() {
        
        guard let device = captureDevice?.device else { return }
        let newScaleFactor = minMaxZoom(3, device: device)
        lastZoomFactor = minMaxZoom(newScaleFactor, device: device)
        update(scale: lastZoomFactor, device: device)
        
    }
    
    private func update(scale factor: CGFloat, device:AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = factor
        } catch {
            DebugPrint(message: "\(error.localizedDescription)", function: .updateCameraScale)
        }
    }
    
    @objc
    private func pinch(_ pinch: UIPinchGestureRecognizer) {
        
        guard let device = captureDevice?.device else { return }
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor, device: device)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor,device: device)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor,device: device)
            update(scale: lastZoomFactor,device: device)
        default: break
        }
        
    }
    
    private func setupPinchGesture() {
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:#selector(pinch(_:)))
        self.previewView.addGestureRecognizer(pinchRecognizer)
        overlayView.frame = previewView.bounds
        overlayView.backgroundColor = UIColor.clear
        previewSize = previewView.frame.size
        previewView.addSubview(overlayView)
        
    }
    
    private func setupBlinkLabel(_ installedDate: Date) {
        
        let calendar = Date()
        let calen = Calendar.current
        let days = calen.dateComponents([.day], from: installedDate, to: calendar)
        if days.day ?? 0 <= 30 && days.day ?? 0 >= 0 {
            self.islicenceExpired = false
        } else {
            self.islicenceExpired = true
        }
        
        let expireLabelItem = UILabel()
        expireLabelItem.translatesAutoresizingMaskIntoConstraints = false
        expireLabelItem.numberOfLines = 0
        expireLabelItem.alpha = 0
        expireLabelItem.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        expireLabelItem.textAlignment = .center
        expireLabelItem.text = "The Scanflow SDK licence validation failed. \nYour licence key has expired!"
        self.expireLabel = expireLabelItem
        self.previewView.addSubview(expireLabelItem)
        
        
        let blinkLabelItem = UILabel()
        blinkLabelItem.translatesAutoresizingMaskIntoConstraints = false
        blinkLabelItem.backgroundColor = .systemGreen
        blinkLabelItem.layer.cornerRadius = 2.5
        blinkLabelItem.clipsToBounds = true
        blinkLabelItem.alpha = 0
        self.blinkLabel = blinkLabelItem
        self.previewView.addSubview(blinkLabelItem)
        
        NSLayoutConstraint.activate([
            
            expireLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            expireLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            expireLabel.leftAnchor.constraint(equalTo: previewView.leftAnchor, constant: 30),
            expireLabel.rightAnchor.constraint(equalTo: previewView.rightAnchor, constant: -30),
            
            blinkLabel.heightAnchor.constraint(equalToConstant: 5),
            blinkLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            blinkLabel.leftAnchor.constraint(equalTo: previewView.leftAnchor, constant: 30),
            blinkLabel.rightAnchor.constraint(equalTo: previewView.rightAnchor, constant: -30)
            
        ])
        
    }
    
    func createOverlay() -> UIView {
        
        //        print(previewView.bounds)
        //        print(previewView.frame)
        //
        //        print(MV.SCREEN_WIDTH)
        //        print(MV.SCREEN_HEIGHT)
        //
        //        print(self.previewView.bounds.width - maskSize.width)
        //
        //        print(maskContainer.origin.x)
        //        print(maskContainer.origin.y)
        
        let overlayView = UIView(frame: self.previewView.bounds)
        overlayView.backgroundColor = UIColor.clear
        
        
        let path = CGMutablePath()
        path.addRoundedRect(in: maskContainer, cornerWidth: 2, cornerHeight: 2)
        path.closeSubpath()
        
        let shape = CAShapeLayer()
        shape.path = path
        shape.lineWidth = 5.0
        shape.strokeColor = UIColor.white.cgColor
        shape.fillColor = UIColor.white.cgColor
        
        //        overlayView.layer.addSublayer(shape)
        
        path.addRect(CGRect(origin: .zero, size: overlayView.frame.size))
        
        let maskLayer = CAShapeLayer()
        maskLayer.backgroundColor = UIColor.black.cgColor
        maskLayer.path = path
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        // MARK: - Edged Corners
        
        let cornerRadius = self.previewView.layer.cornerRadius
        
        if self.previewView.layer.cornerRadius > cornerLength { self.previewView.layer.cornerRadius = cornerLength }
        if cornerLength > maskContainer.width / 2 { cornerLength = maskContainer.width / 2 }
        
        let upperLeftPoint = CGPoint(x: maskContainer.minX, y: maskContainer.minY)
        let upperRightPoint = CGPoint(x: maskContainer.maxX, y: maskContainer.minY)
        let lowerRightPoint = CGPoint(x: maskContainer.maxX, y: maskContainer.maxY)
        let lowerLeftPoint = CGPoint(x: maskContainer.minX, y: maskContainer.maxY)
        
        let upperLeftCorner = UIBezierPath()
        upperLeftCorner.move(to: upperLeftPoint.offsetBy(dx: 0, dy: cornerLength))
        upperLeftCorner.addArc(withCenter: upperLeftPoint.offsetBy(dx: cornerRadius, dy: cornerRadius),
                               radius: self.previewView.layer.cornerRadius, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        upperLeftCorner.addLine(to: upperLeftPoint.offsetBy(dx: cornerLength, dy: 0))
        
        let upperRightCorner = UIBezierPath()
        upperRightCorner.move(to: upperRightPoint.offsetBy(dx: -cornerLength, dy: 0))
        upperRightCorner.addArc(withCenter: upperRightPoint.offsetBy(dx: -cornerRadius, dy: cornerRadius),
                                radius: self.previewView.layer.cornerRadius, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
        upperRightCorner.addLine(to: upperRightPoint.offsetBy(dx: 0, dy: cornerLength))
        
        let lowerRightCorner = UIBezierPath()
        lowerRightCorner.move(to: lowerRightPoint.offsetBy(dx: 0, dy: -cornerLength))
        lowerRightCorner.addArc(withCenter: lowerRightPoint.offsetBy(dx: -cornerRadius, dy: -cornerRadius),
                                radius: self.previewView.layer.cornerRadius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        lowerRightCorner.addLine(to: lowerRightPoint.offsetBy(dx: -cornerLength, dy: 0))
        
        let bottomLeftCorner = UIBezierPath()
        bottomLeftCorner.move(to: lowerLeftPoint.offsetBy(dx: cornerLength, dy: 0))
        bottomLeftCorner.addArc(withCenter: lowerLeftPoint.offsetBy(dx: cornerRadius, dy: -cornerRadius),
                                radius: self.previewView.layer.cornerRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        bottomLeftCorner.addLine(to: lowerLeftPoint.offsetBy(dx: 0, dy: -cornerLength))
        
        let combinedPath = CGMutablePath()
        combinedPath.addPath(upperLeftCorner.cgPath)
        combinedPath.addPath(upperRightCorner.cgPath)
        combinedPath.addPath(lowerRightCorner.cgPath)
        combinedPath.addPath(bottomLeftCorner.cgPath)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = combinedPath
        shapeLayer.strokeColor = lineColor.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = lineCap
        
        overlayView.layer.addSublayer(shapeLayer)
        
        
        overlayView.layer.mask = maskLayer
        overlayView.clipsToBounds = true
        return overlayView
        
    }
    
    /**
     This method resumes an interrupted AVCaptureSession.
     */
    func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> ()) {
        
        sessionQueue.async {
            self.startSession()
            
            DispatchQueue.main.async {
                completion(self.isSessionRunning)
            }
        }
    }
    
    /**
     This method starts the AVCaptureSession
     **/
    func startSession() {
        self.session.startRunning()
        self.isSessionRunning = self.session.isRunning
    }
    
    // MARK: Session Configuration Methods.
    /**
     This method requests for camera permissions and handles the configuration of the session and stores the result of configuration.
     */
    
    private func attemptToConfigureSession() {
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.cameraConfiguration = .success
            
        case .notDetermined:
            self.sessionQueue.suspend()
            self.requestCameraAccess(completion: { (granted) in
                self.sessionQueue.resume()
            })
            
        case .denied:
            self.cameraConfiguration = .permissionDenied
            
        default:
            break
        }
        
        self.sessionQueue.async {
            self.configureSession()
        }
    }
    
    /**
     This method requests for camera permissions.
     */
    private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
        
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            if !granted {
                self.cameraConfiguration = .permissionDenied
            } else {
                self.cameraConfiguration = .success
            }
            completion(granted)
        }
        
    }
    
    
    /**
     This method handles all the steps to configure an AVCaptureSession.
     */
    private func configureSession() {
        
        guard cameraConfiguration == .success else {
            return
        }
        session.beginConfiguration()
        
        // Tries to add an AVCaptureDeviceInput.
        guard addVideoDeviceInput() == true else {
            self.session.commitConfiguration()
            self.cameraConfiguration = .failed
            return
        }
        
        // Tries to add an AVCaptureVideoDataOutput.
        guard addVideoDataOutput() else {
            self.session.commitConfiguration()
            self.cameraConfiguration = .failed
            return
        }
        
        session.commitConfiguration()
        self.cameraConfiguration = .success
    }
    
    /**
     This method tries to add an AVCaptureDeviceInput to the current AVCaptureSession.
     */
    //MARK: - Add  VideoDeviceInput
    
    private func addVideoDeviceInput() -> Bool {
        
        /**Tries to get the default back camera.
         */
        guard let camera  = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            fatalError("Cannot find camera")
        }
                
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            camera.videoZoomFactor = CGFloat(3)
        } catch {
            DebugPrint(message: "\(error.localizedDescription)", function: .updateCameraScale)
        }
        
        
        //camera.automaticallyEnablesLowLightBoostWhenAvailable = true
        
        do {
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            
            self.captureDevice = videoDeviceInput
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                return true
            } else {
                return false
            }
            
        } catch {
            fatalError("Cannot create video device input")
        }
    }
    
    /**
     This method tries to add an AVCaptureVideoDataOutput to the current AVCaptureSession.
     */
    private func addVideoDataOutput() -> Bool {
        
        let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            return true
        }
        return false
    }
    
    // MARK: Notification Observer Handling
    func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedManager.sessionRuntimeErrorOccurred(notification:)), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedManager.sessionWasInterrupted(notification:)), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedManager.sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    
    // MARK: Notification Observers
    
    @objc
    func sessionWasInterrupted(notification: Notification) {
        
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reasonIntegerValue = userInfoValue.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            DebugPrint(message: "Capture session was interrupted with reason \(reason)", function: .longDistance)
            
            var canResumeManually = false
            if reason == .videoDeviceInUseByAnotherClient {
                canResumeManually = true
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                canResumeManually = false
            }
            
            self.delegate?.sessionWasInterrupted(canResumeManually: canResumeManually)
            
        }
    }
    
    @objc
    func sessionInterruptionEnded(notification: Notification) {
        self.delegate?.sessionInterruptionEnded()
    }
    
    @objc
    func sessionRuntimeErrorOccurred(notification: Notification) {
        
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        
        DebugPrint(message: "Capture session runtime error: \(error)", function: .longDistance)
        
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.startSession()
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.sessionRunTimeErrorOccurred()
                    }
                }
            }
        } else {
            self.delegate?.sessionRunTimeErrorOccurred()
            
        }
    }
    
}


/**
 AVCaptureVideoDataOutputSampleBufferDelegate
 */
extension CameraFeedManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var hintsZxing:ZXDecodeHints {
        let formats = ZXDecodeHints()
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 1))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 2))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 3))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 4))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 5))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 6))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 7))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 8))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 9))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 10))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 11))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 12))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 13))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 14))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 15))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 16))
        formats.addPossibleFormat(ZXBarcodeFormat.init(rawValue: 17))
        return formats
    }
    
    
    @objc
    func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            DebugPrint(message: error.localizedDescription, function: .longDistance)
        } else {
            DebugPrint(message: "Your image has been saved to your photos. \(contextInfo.debugDescription)", function: .imageSaved)
        }
    }
    
    /** This method delegates the CVPixelBuffer of the frame seen by the camera currently.
     */
    
    //    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    //
    //        // Get the metadata object.
    //            let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
    //
    //            if metadataObj.type == AVMetadataObject.ObjectType.qr {
    //                // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
    ////                let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
    ////                qrCodeFrameView?.frame = barCodeObject!.bounds
    //
    //                if metadataObj.stringValue != nil {
    //                    let data = metadataObj.stringValue
    //                    print("Apple native output: \(data) Time: \(YoloV4Classifier.shared.getCurrentMillis())")
    //
    //                }
    //            }
    //
    //    }
    
    
    private func getBrightnessValue(sampleBuffer: CMSampleBuffer) -> Double {
        
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
        guard let brightnessValue = exifData?[kCGImagePropertyExifBrightnessValue as String] as? Double else {
            return 0
        }
        return brightnessValue
        
    }
    
    //MARK: - Capture Output Delegate
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard !self.islicenceExpired else {
            self.expireLabel.alpha = 1
            return
        }
        
        frameCount = frameCount + 1
        
        if frameCount < 4 {
            return
        }
        
        // Converts the CMSampleBuffer to a CVPixelBuffer.
        
        DebugPrint(message: "Sample buffer to Pixel buffer", function: .captureOutput)
        
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        guard var imagePixelBuffer = pixelBuffer else {
            return
        }
        
        //MARK: - Low light integration
        
        DebugPrint(message: "Before brightness", function: .captureOutput)
        
        let brightnessLevel = getBrightnessValue(sampleBuffer: sampleBuffer)
        
        DebugPrint(message: "Brightness Value: \(brightnessLevel)", function: .captureOutput)


        if brightnessLevel < 0.5 {
            
            DebugPrint(message: "Low Brightness image", function: .captureOutput)
            
            let bufferResult = imagePixelBuffer.setBrightnessContrastAndroidOpencv()
            
            let imgHighBright = bufferResult.toImage()
            
            DebugPrint(message: "Brightness image", function: .captureOutput)
            
            imagePixelBuffer = imgHighBright.toPixelBuffer()
            
            DebugPrint(message: "After brightness pixel", function: .captureOutput)
            
        }
        
        YoloV4Classifier.shared.runModelNew(onFrame: imagePixelBuffer, previewSize: self.previewSize!) { result in
            
            guard let displayResult = result else {
                return
            }
            
            if displayResult.inferences.count == 0 {
                self.delegate?.outputData(str: "", codeType: "QR Code")
                self.drawAfterPerformingCalculations(onInferences: displayResult.inferences,
                                                     withImageSize: CGSize.zero,
                                                     isValidResult: false)
            }
            
            for inference in displayResult.inferences {
                
                self.processResult(cropImage: inference.outputImage,
                                   previewWidth: inference.previewWidth,
                                   previewHeight: inference.previewHeight,
                                   inference: inference)
                
            }
            
            DebugPrint(message: "******* BEFORE DRAW", function: .captureOutput)
            
            DispatchQueue.main.async {
                // Draws the bounding boxes and displays class names and confidence scores.
                //self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: 0.0, height: 0.0))
                //                 self.drawAfterPerformingCalculations(onInferences: displayResult.inferences,
                //                                                     withImageSize: CGSize(width: 0.0, height: 0.0),
                //                                                     isValidResult: true)
                DebugPrint(message: "******* AFTER DRAW", function: .captureOutput)
                
            }
            
        }
        //
        //        for inference in locResult!.inferences {
        //                self.processResult(cropImage: inference.outputImage,previewWidth: inference.previewWidth,previewHeight: inference.previewHeight, inference: inference)
        //            }
        //
        //            //      let width = CVPixelBufferGetWidth(pixelBuffer)
        //            //      let height = CVPixelBufferGetHeight(pixelBuffer)
        //
        //
        //            print("******* BEFORE DRAW: \(YoloV4Classifier.shared.getCurrentMillis())")
        //
        //            // Draws the bounding boxes and displays class names and confidence scores.
        //        self.drawAfterPerformingCalculations(onInferences: locResult!.inferences, withImageSize: CGSize(width: 0.0, height: 0.0))
        //            print("****** AFTER DRAW: \(YoloV4Classifier.shared.getCurrentMillis())")
        //
        //        }
        //        let src = Mat(uiImage: UIImage(named: "long_distance.jpg")!)
        ////
        //        let dst = Mat()
        //        opencv2.Core.normalize(src: src, dst: dst, alpha: 1.0, beta: 127.5, norm_type: NormTypes.NORM_INF)
        //      guard let displayResult = result else {
        //          return
        //      }
    }
    
    
    internal func processResult(cropImage: UIImage,
                                previewWidth: CGFloat,
                                previewHeight: CGFloat,
                                inference: Inference) {
        
        if inference.className == "QR" {
            
            var resultImage = UIImage()
            if isQrLongDistance(image: cropImage,
                                previewWidth: previewWidth,
                                previewHeight: previewHeight) {
                
                //print("QR Long Distance")
                resultImage = cropImage.upscaleQRcode()
                resultImage = SuperResolution.shared.convertImgToSRImg(inputImage: resultImage) ?? UIImage()
                //print("UPSCALE RESIZE",resultImage.size)
                
            } else {
                resultImage = cropImage
            }
            
            
            originalBufferImage = cropImage

            let imgSize = __CGSizeEqualToSize(resultImage.size, .zero)
            
            if !imgSize {
                
                let points = NSMutableArray()
                let mat = Mat.init(uiImage: resultImage)
                let result = WeChatQRCode().detectAndDecode(img: mat, points: points)
                DebugPrint(message: "WECHAT RESULT: \n \(result), \(result.count)", function: .processResults)
                
                if result.first != nil && result.first != "" {
                    self.delegate?.outputData(str: result.first ?? "", codeType: "QR Code")
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    DebugPrint(message: "QR RESULT IN: \(YoloV4Classifier.shared.getCurrentMillis())", function: .processResults)
                    self.drawAfterPerformingCalculations(onInferences: [inference],
                                                         withImageSize: resultImage.size,
                                                         isValidResult: true)
                } else {
                    
                    //print("Result first value: \(result.first ?? "Unknown or nil")")
                    YoloV4Classifier.shared.isProduction() ? nil : UIImageWriteToSavedPhotosAlbum(originalBufferImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
                    self.delegate?.outputData(str: "", codeType: "QR Code")
                    self.drawAfterPerformingCalculations(onInferences: [inference],
                                                         withImageSize: resultImage.size,
                                                         isValidResult: false)
                    
                }
                
            } else {
                
                self.delegate?.outputData(str: "", codeType: "QR Code")
                YoloV4Classifier.shared.isProduction() ? nil : UIImageWriteToSavedPhotosAlbum(originalBufferImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
                self.drawAfterPerformingCalculations(onInferences: [inference],
                                                     withImageSize: resultImage.size,
                                                     isValidResult: false)
            }
            
        } else {
            
            let resultImage:UIImage?
            if isBarcodeLongDistance(image: cropImage,previewWidth: previewWidth,previewHeight: previewHeight) {
                
                DebugPrint(message: "BAR Long Distance", function: .longDistance)
                resultImage = cropImage.upscaleBarcode()
                
            } else {
                
                resultImage = cropImage
                
            }
            
            originalBufferImage = resultImage

            let rotatedImage = self.processImage(image: resultImage ?? UIImage())
            self.decodeZxing(image: rotatedImage, inference: inference)
            
        }
        
    }
    
    //MARK: - Decode Zxing
    
    func decodeZxing(image: UIImage, inference: Inference) {
        
        //self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: 0.0, height: 0.0))
        
        let source: ZXLuminanceSource = ZXCGImageLuminanceSource(cgImage: image.cgImage)
        let binazer = ZXHybridBinarizer(source: source)
        let bitmap = ZXBinaryBitmap(binarizer: binazer)
        //        print("###### BITMAP IMAGE WIDTH \(bitmap?.width ?? 0)")
        
        let reader = ZXMultiFormatReader()
        let hints = hintsZxing
        //print("###### DECODE BITMAP",try? reader.decode(bitmap, hints: hints))
        
        if let result = try? reader.decode(bitmap, hints: hints) {
            
            
            let formate = result.barcodeFormat.rawValue
            let codeType = self.getValidBarCode(Int(formate))
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            self.delegate?.outputData(str: result.text ?? "", codeType: codeType)
            DebugPrint(message: "BAR RESULT IN", function: .processResults)
            self.drawAfterPerformingCalculations(onInferences: [inference],
                                                 withImageSize: image.size,
                                                 isValidResult: true)
            
            DebugPrint(message: "RESULT 3: \(result.text ?? "")", function: .processResults)
            
            //self.overlayView.isHidden = false
            
            
        } else {
            
            self.delegate?.outputData(str: "", codeType: "QR Code")
            self.drawAfterPerformingCalculations(onInferences: [inference],
                                                 withImageSize: image.size,
                                                 isValidResult: false)
            
            //self.overlayView.isHidden = true
            
            //print("###### DECODE BITMAP Nil")
            YoloV4Classifier.shared.isProduction() ? nil : UIImageWriteToSavedPhotosAlbum(originalBufferImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            
        }
        
    }
    
    
    //MARK: - Draw Bounding Box
    
    func drawAfterPerformingCalculations(onInferences inferences: [Inference],
                                         withImageSize imageSize: CGSize,
                                         isValidResult: Bool) {
        
        self.overlayView.objectOverlays = []
        
        DispatchQueue.main.async {
            // Hands off drawing to the OverlayView
            self.overlayView.setNeedsDisplay()
        }
        
        
        let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        
        guard !inferences.isEmpty else {
            return
        }
        
        var objectOverlays: [ObjectOverlay] = []
        
        for inference in inferences {
            
            DispatchQueue.main.async {
                
                // Translates bounding box rect to current view.
                var convertedRect = inference.rect
                //          print("overlayView width",self.overlayView.bounds.size.width)
                //          print("overlayView height",self.overlayView.bounds.size.height)
                //          print("inference.rect",inference.rect)
                
                if convertedRect.origin.x < 0 {
                    convertedRect.origin.x = self.edgeOffset
                }
                
                if convertedRect.origin.y < 0 {
                    convertedRect.origin.y = self.edgeOffset
                }
                
                if convertedRect.maxY > self.overlayView.bounds.maxY {
                    convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
                }
                
                if convertedRect.maxX > self.overlayView.bounds.maxX {
                    convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
                }
                
                let confidenceValue = Int(inference.confidence * 100.0)
                let string = "\(inference.className)  (\(confidenceValue)%)"
                
                let size = string.size(usingFont: displayFont)
                DebugPrint(message: "Converted Rect: \(convertedRect)", function: .drawAfterCalculation)
                
                //inference.displayColor
                
                let rectColor = isValidResult ? UIColor.opti_scan_bounding_box_color : UIColor.clear
                let objectOverlay = ObjectOverlay(name: string,
                                                  borderRect: inference.boundingRect,
                                                  nameStringSize: size,
                                                  color: rectColor,
                                                  font: displayFont)
                
                DebugPrint(message: "BOUNDING Rect: \(inference.boundingRect)", function: .drawAfterCalculation)
                
                objectOverlays.append(objectOverlay)
                
            }
            
        }
        
        DispatchQueue.main.async {
            // Hands off drawing to the OverlayView
            self.draw(objectOverlays: objectOverlays)
        }
        
    }
    
    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    func draw(objectOverlays: [ObjectOverlay]) {
        //        print("&&&&&& &&&&&&& &&&&&&& OBJECT OVERLAY",objectOverlays)
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.clipsToBounds = true
        self.overlayView.setNeedsDisplay()
    }
    
    private func isQrLongDistance(image:UIImage,previewWidth:CGFloat,previewHeight:CGFloat) ->Bool{
        let isLong = LongDistance().isLongDistanceQRImage(cropImageWidth: image.size.width, cropImageHeight: image.size.height, previewWidth: previewWidth, previewHeight: previewHeight)
        return isLong
    }
    
    private func isBarcodeLongDistance(image:UIImage,previewWidth:CGFloat,previewHeight:CGFloat) ->Bool{
        let isLong = LongDistance().isLongDistanceBarcodeImage(cropImageWidth: image.size.width, cropImageHeight: image.size.height, previewWidth: previewWidth, previewHeight: previewHeight)
        return isLong
    }
    
    
    
    func processImage(image:UIImage) -> UIImage {
        
        //       var degree:Double = 0.0
        let inputImageMat = Mat.init(uiImage: image)
        let lines:Mat = initMatSetup(bitmap: image)
        //       print("BEFORE ROTATE TIME: \(getCurrentMillis())")
        let angleResult = self.detectRotationAngle(binaryImage: lines)
        let rotatedImage = self.rotateImage(imageMat: inputImageMat, angle: angleResult)
        //       print("AFTER ROTATE TIME: \(getCurrentMillis())")
        return rotatedImage
        
    }
    
    private func initMatSetup(bitmap:UIImage) -> Mat {
        
        // print("BEFORE initMatSetup: \(getCurrentMillis())")
        
        let mat = Mat.init(uiImage: bitmap)
        var rgbMat = mat
        let grayMat = mat
        var destination:Mat = Mat(rows: rgbMat.rows(), cols: rgbMat.cols(), type: rgbMat.type())
        Imgproc.cvtColor(src: rgbMat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
        
        destination = grayMat
        let element = Imgproc.getStructuringElement(shape: MorphShapes.MORPH_RECT, ksize: Size2i(width: 5, height: 5))
        Imgproc.erode(src: grayMat, dst: destination, kernel: element)
        
        rgbMat = destination
        let element1 = Imgproc.getStructuringElement(shape: MorphShapes.MORPH_RECT, ksize: Size2i(width: 5, height: 5))
        Imgproc.dilate(src: rgbMat, dst: destination, kernel: element1)
        
        //Detecting the edges
        let edges = mat
        Imgproc.Canny(image: destination, edges: edges, threshold1: 50.0, threshold2: 200.0)
        //Detecting the hough lines from (canny)
        let lines = mat
        Imgproc.HoughLinesP(image: edges, lines: lines, rho: 0.8, theta: .pi / 360, threshold: 50, minLineLength: 50.0, maxLineGap: 10.0)
        // print("AFTER initMatSetup: \(getCurrentMillis())")
        return lines
        
    }
    
    private func detectRotationAngle(binaryImage: Mat) -> Double {
        
        var angle:Double = 0.0
        let debugImage:Mat = binaryImage.clone()
        for x in 0..<binaryImage.cols(){
            var vec = [Double]()
            vec = binaryImage.get(row: 0, col: x)
            let x1:Double = vec[0]
            let y1:Double = vec[1]
            let x2:Double = vec[2]
            let y2:Double = vec[3]
            let start :Point2i = Point2i(x: Int32(x1), y: Int32(y1))
            let end : Point2i = Point2i(x: Int32(x2), y: Int32(y2))
            
            //Draw line on the "debug" image for visualization
            Imgproc.line(img: debugImage, pt1: start, pt2: end, color: Scalar(255.0, 255.0, 0), thickness: 5)
            
            //Calculate the angle we need
            angle = calculateAngleFromPoints(start: start, end: end);
        }
        //        print("AFTER ROTATE IMAGE: \(getCurrentMillis())")
        
        return angle;
    }
    
    
    //  From an end point and from a start point we can calculate the angle
    
    private func calculateAngleFromPoints(start: Point2i, end: Point2i) -> Double {
        
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let atan:Double = atan2(Double(deltaY), Double(deltaX))
        let val = atan * (180 / .pi)
        return val
        
    }
    
    private func rotateImage(imageMat: Mat, angle: Double) -> UIImage {
        
        DebugPrint(message: "ACTUAL DEGREE -->>> \(angle)", function: .rotateImage)
        
        var image = imageMat.toUIImage()
        
        if imageMat.size().height > imageMat.size().width {
            
            DebugPrint(message: "ACTUAL DEGREE Size -->>> \(imageMat.size())", function: .rotateImage)
            let size = imageMat.size()
            let height = Double(size.height)
            
            DispatchQueue.main.async {
                
                let imageV = UIImageView(frame: CGRect(x: 0, y: 0, width: height, height: height))
                imageV.backgroundColor = .white
                imageV.image = image
                imageV.contentMode = .center
                image = UIImage(view: imageV)
            }
            
            DebugPrint(message: "ACTUAL DEGREE Size after conversion -->>> \(image.size)", function: .rotateImage)
            
        } else {
            
            let size = imageMat.size()
            let width = Double(size.width)
            
            DispatchQueue.main.async {
                
                let imageV = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: width))
                imageV.backgroundColor = .white
                imageV.image = image
                imageV.contentMode = .center
                image = UIImage(view: imageV)
                
            }
            
            
            DebugPrint(message: "ACTUAL DEGREE Size after conversion -->>> \(image.size)", function: .rotateImage)
            
        }
                
        
        let locImageMat = Mat.init(uiImage: image)
        
        //Get the rotation matrix
        
        let imgCenter = Point2f(x: Float(locImageMat.cols()) / 2, y: Float(locImageMat.rows()) / 2)
        
        DebugPrint(message: "ROTATION PERFORM", function: .rotateImage)
        
        let rotMtx = Imgproc.getRotationMatrix2D(center: imgCenter, angle: angle, scale: 1.0)
        
        Imgproc.warpAffine(src: locImageMat, dst: locImageMat, M: rotMtx, dsize: Size2i(width:Int32(image.size.width) , height: Int32(image.size.height)))
        
        let img = locImageMat.toUIImage()
        
        return img
        
        
    }
    
    
}
