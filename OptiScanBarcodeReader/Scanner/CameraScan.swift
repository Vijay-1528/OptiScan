

import UIKit
import Foundation
import AVFoundation
import opencv2
import Vision



public class CameraScan: NSObject, ICameraScan {
    
    //MARK: - Private Variables
    private var events: ICameraScanCallback?
    private var scannerOverlayPreview:ScannerOverlayPreviewLayer?
    internal var scannerView :UIView?
    internal var selectedScannerType:ScannerType = .qrcode
    internal var scannerViewSize:CGSize = .zero
    private var captureDevice:AVCaptureDeviceInput?
    private var lastZoomFactor: CGFloat = 1.0
    private var leastCounterClockMin:Double = 0.0
    private var leastClockMin:Double = 0.0
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 3.0
    
    private let scannerOverlayWidth: CGFloat = 300.0
    private let scannerOverlayheight: CGFloat = 300.0
    internal var overlayView = OverlayView()
    internal var previewSize:CGSize = .zero
    
//    let sharedObject:YoloV4Classifier? = YoloV4Classifier(threadCount: 1)
//    var yoloV4Classifier:YoloV4Classifier? = YoloV4Classifier.shared
//    lazy var yoloV4Classifier: YoloV4Classifier? = {
//    }()
//    internal var yoloV4Classifier: YoloV4Classifier? =
//    YoloV4Classifier(modelFileInfo: YoloV4.modelInfo, labelsFileInfo: YoloV4.labelsInfo)
    var barDecodeCount:Int = 0
    
    var frameCount: Int = 0

    private lazy var getScannerView: UIView = {
        let scanview = scannerView
        return scanview ?? UIView()
    }()
    
    lazy private var takePhotoButton: UIButton = {
        let button = UIButton()
        var mainScreen = UIScreen.main.bounds
        button.frame =  CGRect(x: mainScreen.size.width / 2 - 70 / 2, y: mainScreen.height - 130, width: 70, height: 70)
        button.layer.cornerRadius = 35.0
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 3.0
        button.addTarget(self, action: #selector(handleTakePhoto), for: .touchUpInside)
        button.backgroundColor = UIColor.red
        return button
    }()
    
    lazy  var previewImage: UIImageView = {
        let image = UIImageView()
        var mainScreen = UIScreen.main.bounds
        image.frame =  CGRect(x: 0, y: mainScreen.height - 450, width:mainScreen.width , height: 450)
        image.contentMode = .scaleAspectFit
        image.backgroundColor = UIColor.gray
        return image
    }()
    
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoSampleBufferQueue = DispatchQueue(label: "videoSampleBufferQueue")

    //MARK: - Internal variables
    internal var captureSession: AVCaptureSession?
    internal var result: Result?
    internal let edgeOffset: CGFloat = 2.0
    

    //MARK: - Initialization
    convenience init(view: UIView, events: ICameraScanCallback, scannerType: ScannerType) {
        self.init()
//        print("#### yoloV4Classifier",self.yoloV4Classifier)
//         guard YoloV4Classifier(threadCount: 1, selectedScannerType: self.selectedScannerType) != nil else {
//           fatalError("Failed to load model")
//         }
        print("****** Camera scan init: \(getCurrentMillis())")
        DispatchQueue.main.async {
            YoloV4Classifier.shared.initializeModelInfo(selectedScannerType: scannerType)
            print("****** YoloV4Classifier init done: \(self.getCurrentMillis())")
        }
        
//        overlayView.clearsContextBeforeDrawing = true
        self.events = events
        scannerView = view
        selectedScannerType = scannerType
        self.frameCount = 0
        
        DispatchQueue.main.async {
            self.doInitialSetup()
            print("****** doInitialSetup init done: \(self.getCurrentMillis())")
        }
    }
    
  
    //MARK: - Public methodsK
   
    public func enableTorch(enable: Bool) {
        toggleFlash(ison: enable)
    }
    
    public func isTorchEnabled() -> Bool {
        var isTorch:Bool = false
        guard
            let device = captureDevice?.device,
            device.hasTorch
        else { return false}
        
        device.unlockForConfiguration()
        isTorch = device.isTorchActive ? true : false
       
        return isTorch
    }
    
    public func optiscanView() -> UIView {
       return self.getScannerView
    }
    
    public func enableScannerBox(enable: Bool) {
        scannerOverlayPreview?.lineColor = enable ? UIColor.white : .clear
    }
    
    public func setupScannerView(view:UIView) -> UIView{
        return scannerView ?? UIView()
    }
    
    public func destroy(){
        self.stopCamera()
    }

    //MARK: - Private Methods
    private var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    internal func startCamera() {
        captureSession?.startRunning()
    }
    
    /// capture settion which allows us to start and stop scanning.
    private func stopCamera() {
//        if captureSession.isRunning {
//            DispatchQueue.global().async {
        captureSession?.stopRunning()
        captureSession = nil
//            }
//        }
        self.events?.onScanningDidStop()
    }
    
    private func scanningDidFail(message:String) {
        self.events?.onScanningDidFail(errorMessage: message)
         captureSession = nil
     }
    
    internal func found(code: String) {
        print("***** Result Found: \(getCurrentMillis())")
        self.events?.onScanningSucceed(code)
    }
   
    private func update(scale factor: CGFloat,device:AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = factor
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    private func toggleFlash(ison:Bool) {
        let device = captureDevice?.device
        device?.setTorch(enable: ison)
    }
    
    private func minMaxZoom(_ factor: CGFloat,device:AVCaptureDevice) -> CGFloat {
        return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
    }
    
    
    @objc private func pinch(_ pinch: UIPinchGestureRecognizer) {
        
        guard let device = captureDevice?.device else { return }
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor,device: device)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor,device: device)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor,device: device)
            update(scale: lastZoomFactor,device: device)
        default: break
        }
    }
    
    @objc private func handleTakePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
            stopCamera()
        }
    }
    
    private func setupUI() {
        
//        let window = UIApplication.shared.keyWindow!
////        window.addSubview(takePhotoButton)
//        window.addSubviews(previewImage)
    }
    
    private func isClockwiseAngle(lines:Mat) -> Bool{
        var plusCount = 0
        var minusCount = 0
        var angle:Double = 0.0
        var anglePlusArray : [Double] = []
        var angleMinusArray : [Double] = []

        for i in 0..<lines.rows() {
            let vec:[Double] = lines.get(row: i, col: 0)
            
            let x1:Double = vec[0]
            let y1:Double = vec[1]
            let x2:Double = vec[2]
            let y2:Double = vec[3]
            
            let start = Point(x: Int32(x1), y: Int32(y1))
            let end = Point(x: Int32(x2), y: Int32(y2))
            
            let deltaX = end.x - start.x
            let deltaY = end.y - start.y
            
            angle = atan2(Double(deltaY), Double(deltaX)) * (180 / .pi)
//            print("Angle %%",angle)
            if (angle > 0) {
                plusCount += 1
                anglePlusArray.append(angle)
                
            } else {
                if angle != 0.0 {
                    angleMinusArray.append(angle.rounded())
                    minusCount += 1
                }
            }
        }
        if plusCount > minusCount {
            leastClockMin = angleMinusArray.sorted().last ?? 0.0
            return true
        }
        else
        {
            leastCounterClockMin = anglePlusArray.sorted().last ?? 0.0
            return false
        }
    }
    
    private func initMatSetup(bitmap:UIImage) -> Mat{
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
    
    private func detectRotationAngle(binaryImage:Mat) -> Double{
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
    //MARK: - Add image to Library
       @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
           if let error = error {
               // we got back an error!
               print(error.localizedDescription)
           } else {
               print("Your image has been saved to your photos. \(contextInfo.debugDescription)")
           }
       }
    
    
    func textToImage(drawText text: String, inImage image: UIImage, atPoint point: CGPoint) -> UIImage {
        let textColor = UIColor.red
        let textFont = UIFont(name: "Helvetica Bold", size: 20)!

        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(image.size, false, scale)

        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            ] as [NSAttributedString.Key : Any]
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

        let rect = CGRect(origin: point, size: image.size)
        text.draw(in: rect, withAttributes: textFontAttributes)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
    
    private func rotateImage(imageMat: Mat, angle:Double) -> UIImage{
        print("ACTUAL DEGREE -->>>",angle)
        
        var image = imageMat.toUIImage()
        
        if imageMat.size().height > imageMat.size().width{
            print("ACTUAL DEGREE Size -->>>",imageMat.size())
            let size = imageMat.size()
            let height = Double(size.height)
            
            DispatchQueue.main.async {
                
                let imageV = UIImageView(frame: CGRect(x: 0, y: 0, width: height, height: height))
                imageV.backgroundColor = .white
                imageV.image = image
                imageV.contentMode = .center
                image = UIImage(view: imageV)
            }
            
            print("ACTUAL DEGREE Size after conversion -->>>",image.size)
            
        }else{
            let size = imageMat.size()
            let width = Double(size.width)
            
            DispatchQueue.main.async {
                // UIView usage
                let imageV = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: width))
                imageV.backgroundColor = .white
                imageV.image = image
                imageV.contentMode = .center
                image = UIImage(view: imageV)
            }
           
            
            print("ACTUAL DEGREE Size after conversion -->>>",image.size)
            
        }
        
//        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        
        let locImageMat = Mat.init(uiImage: image)
        
        //Get the rotation matrix
        
        let imgCenter = Point2f(x: Float(locImageMat.cols()) / 2, y: Float(locImageMat.rows()) / 2)
        
        print("ROTATION PERFORM")
        let rotMtx = Imgproc.getRotationMatrix2D(center: imgCenter, angle: angle, scale: 1.0)
        
        Imgproc.warpAffine(src: locImageMat, dst: locImageMat, M: rotMtx, dsize: Size2i(width:Int32(image.size.width) , height: Int32(image.size.height)))
        
        
//        UIImageWriteToSavedPhotosAlbum(locImageMat.toUIImage(), self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        let img = locImageMat.toUIImage()
        return img
        
        
    }
    
  //  From an end point and from a start point we can calculate the angle
    private func calculateAngleFromPoints(start:Point2i, end:Point2i) -> Double{
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let atan:Double = atan2(Double(deltaY), Double(deltaX))
        let val = atan * (180 / .pi)
        return val
    }
    
   internal func processImage(image:UIImage) -> UIImage{
//       var degree:Double = 0.0
       let inputImageMat = Mat.init(uiImage: image)
       let lines:Mat = initMatSetup(bitmap: image)
//       print("BEFORE ROTATE TIME: \(getCurrentMillis())")
       let angleResult = self.detectRotationAngle(binaryImage: lines)
       let rotatedImage = self.rotateImage(imageMat: inputImageMat, angle: angleResult)
//       print("AFTER ROTATE TIME: \(getCurrentMillis())")
       return rotatedImage
//        let (angle, linesDrawn) = calculateAngle(lines: lines)
       // print("BEFORE processImage: \(getCurrentMillis())")

//        if self.selectedScannerType == .qrcode {
//            if self.isClockwiseAngle(lines: linesDrawn) {degree = -(360 + leastClockMin)}
//            else{ degree = 360 - leastCounterClockMin}
//        }
//        else
//        {
//            print("%% ANGLE",angle)
//            if angle == 0.0 || angle == -90.0{
//                degree = 0.0
//                print("this is 0.0 deg")
//            }
//           else{
//                if self.isClockwiseAngle(lines: linesDrawn) {
//                    degree = -(360 + leastClockMin)
//                    print("Least Clock min",leastClockMin)
//                }
//                else{
//                    degree = 360 - leastCounterClockMin
//                    print("Least CounterClock min",leastCounterClockMin)
//                }
//           }
//            print("Final Degree ####",degree)
//
//        }
////        self.previewImage.image = image.rotate(radians: Float(degree)) ?? UIImage()
//        return image.rotate(radians: Float(degree)) ?? UIImage()

    }
    
    private func calculateAngle(lines:Mat) -> (Double,Mat){
     //   print("BEFORE calculateAngle: \(getCurrentMillis())")

        //Calculate the start and end point and the angle
        var angle:Double = 0.0
        for i in 0..<lines.rows(){
            let vec:[Double] = lines.get(row: i, col: 0)
            let x1:Double = vec[0]
            let y1:Double = vec[1]
            let x2:Double = vec[2]
            let y2:Double = vec[3]
            let start = Point(x: Int32(x1), y: Int32(y1))
            let end = Point(x: Int32(x2), y: Int32(y2))
            Imgproc.line(img: lines, pt1: start, pt2: end, color: Scalar(255, 255, 0), thickness: 5)
            let deltaX = end.x - start.x
            let deltaY = end.y - start.y
            angle = atan2(Double(deltaY), Double(deltaX)) * (180 / .pi)
        }
       // print("AFTER calculateAngle: \(getCurrentMillis())")
        return (angle,lines)
    }
    
    private func deg2rad(_ number: CGFloat) -> CGFloat {
        return number * .pi / 180
    }

    
    private func rad2deg(_ number: Double) -> Double {
        return number * 180 / .pi
    }
    
     func getCurrentMillis()->String {
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MMM-dd HH:mm:ss.SSSS"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        return dateString
    }
    
    private func doInitialSetup(){
        print("****** Initial setup : \(getCurrentMillis())")
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        var err: NSError?
        let videoInput: AVCaptureDeviceInput
//        if videoCaptureDevice.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus) {
//            do {
//                try videoCaptureDevice.lockForConfiguration()
//
//                videoCaptureDevice.focusMode = .autoFocus
//
//                videoCaptureDevice.unlockForConfiguration()
//            } catch {
//                print("Torch could not be used")
//            }
//        } else {
//            print("Torch is not available")
//        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            captureDevice = videoInput

            
        } catch let errorValue as NSError {
            err = errorValue
            return
        }
        
        if (captureSession?.canAddInput(videoInput) == false || err != nil) {
            scanningDidFail(message: err?.localizedDescription ?? "")
            return
        } else {

            captureSession?.addInput(videoInput)
        }
      
        videoOutput.setSampleBufferDelegate(self, queue: videoSampleBufferQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
        

        if captureSession?.canAddOutput(videoOutput) == true{
            captureSession?.addOutput(videoOutput)
        }
       

        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession?.canAddOutput(metadataOutput) == false || err != nil) {
            scanningDidFail(message: err?.localizedDescription ?? "")
            return
        }
        else {
            captureSession?.addOutput(metadataOutput)
            //            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            // metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        }
        if let capture = captureSession{
            capture.addOutput(photoOutput)
        }
        
        
        scannerOverlayPreview = ScannerOverlayPreviewLayer(session: captureSession!)
        scannerOverlayPreview?.frame = scannerView!.bounds
        scannerOverlayPreview?.maskSize = CGSize(width: scannerOverlayWidth, height: scannerOverlayheight)
        scannerOverlayPreview?.videoGravity = .resizeAspectFill
        scannerOverlayPreview?.session?.sessionPreset = .high
        scannerOverlayPreview?.connection?.videoOrientation = .portrait
        scannerView?.layer.addSublayer(scannerOverlayPreview ?? ScannerOverlayPreviewLayer())
        metadataOutput.rectOfInterest = scannerOverlayPreview?.rectOfInterest ?? CGRect.zero
        
        print("****** Done Initial setup : \(getCurrentMillis())")
        
        startCamera()
//        self.setupUI()
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:#selector(pinch(_:)))
        self.scannerView?.addGestureRecognizer(pinchRecognizer)
        scannerViewSize = scannerView?.frame.size ?? CGSize.zero
        overlayView.frame = scannerView!.bounds
        overlayView.backgroundColor = UIColor.clear
        previewSize = scannerView?.frame.size ?? CGSize.zero
        scannerView?.addSubview(overlayView)

    }
        
}
//
////MARK: - AVCaptureMetadataOutputObjectsDelegate
//extension CameraScan: AVCaptureMetadataOutputObjectsDelegate {
//    public func metadataOutput(_ output: AVCaptureMetadataOutput,
//                               didOutput metadataObjects: [AVMetadataObject],
//                               from connection: AVCaptureConnection) {
//        if let metadataObject = metadataObjects.first {
//            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
//        }
//    }
//
//
//}

//MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraScan: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /** This method delegates the CVPixelBuffer of the frame seen by the camera currently.
     */
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        print("****** Before framecount: \(getCurrentMillis())")
        
        
//        frameCount = frameCount + 1
//        
//        if frameCount < 5{
//            return
//        }
//        
        guard let imagePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        
        
//        if output is AVCaptureVideoDataOutput {
//            let sourceImage = imagePixelBuffer.toImage()
//            UIImageWriteToSavedPhotosAlbum(sourceImage , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//
//        }
        
//        let sourceImage = imagePixelBuffer.toImage()
//        UIImageWriteToSavedPhotosAlbum(sourceImage , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

        
        
//
//        if connection.isVideoOrientationSupported {
//                // Work with video samle boofer
//            UIImageWriteToSavedPhotosAlbum(sourceImage , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//
//            } else {
//                // Work with audio sample boofer audio
//            }
//

       
//        let bundle = Bundle(for: type(of: self))
//        guard let imagePath = bundle.path(forResource: "35_1629224730242_orginal", ofType: "jpg") else {
//            print("Failed to load the model file with name:")
//            return
//        }
//        print("IMAGE PATH",imagePath)
//        let image = UIImage(contentsOfFile: imagePath)
//
//        guard let imagePixelBuffer = image?.toPixelBuffer() else  {return}


//        print("LOAD IMAGE SIZE",image?.size)
//        let buffer416 = (image?.toPixelBuffer())!
        
        print("****** Got Image: \(getCurrentMillis())")
        let _ = imagePixelBuffer.toImage()
        //UIImageWriteToSavedPhotosAlbum(imgHighBright , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//        DispatchQueue.main.async {
            self.runModel(onPixelBuffer: imagePixelBuffer)
            print("****** AFTER runModel Capture: \(self.getCurrentMillis())")
//        }
        
//        print("****** BEFORE brightness: \(getCurrentMillis())")
//
//
////        UIImageWriteToSavedPhotosAlbum(imgHighBright , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//
////        let img = pixelBuffer?.toImage()
//
//        let brightnessLevel = sourceImage.brightness
//
//        print("****** After brightness: \(getCurrentMillis())")
//
//        print("brightnessLevel  \(String(describing: brightnessLevel))")
//
//        if brightnessLevel < 10 {
//            print("LOW BRIGHTNESS")
//            let bufferResult = imagePixelBuffer.setBrightnessContrastAndroidOpencv()
//
//            let imgHighBright = bufferResult.toImage()
//
//            print(imgHighBright)
//
//            //UIImageWriteToSavedPhotosAlbum(imgHighBright , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//
//            self.runModel(onPixelBuffer: bufferResult)
//            print("AFTER runModel: \(getCurrentMillis())")
//        } else {
//            print("****** Got Image: \(getCurrentMillis())")
//            let imgHighBright = imagePixelBuffer.toImage()
//            UIImageWriteToSavedPhotosAlbum(imgHighBright , self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//            self.runModel(onPixelBuffer: imagePixelBuffer)
//            print("****** AFTER runModel Capture: \(getCurrentMillis())")
//        }
        
       
      
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("DID DROP BUFFER DELEGATE:")
        connection.videoOrientation = AVCaptureVideoOrientation.portrait
    }
    
   private func getBrightness(sampleBuffer: CMSampleBuffer) -> Double {
//       print("BEFORE getBrightness: \(getCurrentMillis())")
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
//        print("EXIF DATA",exifData)
        let brightnessValue : Double = exifData?[kCGImagePropertyExifBrightnessValue as String] as! Double
//        print("%%% %%% %% BRIGHTNESS",brightnessValue)
//       print("AFTER getBrightness: \(getCurrentMillis())")
        return brightnessValue
    }
}




extension CameraScan: AVCapturePhotoCaptureDelegate {
   
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("******* didFinishProcessingPhoto delegate")
        guard let imageData = photo.fileDataRepresentation() else { return }
        print("BEFORE ROTATE: \(getCurrentMillis())")
//        let img = UIImage(data: imageData) ?? UIImage()
////        let image = UIImage(named: "cropeepdsf.jpg", in: Bundle(for: type(of: self)), compatibleWith: nil) ?? UIImage()
//        let previewImage = self.processImage(image:  img)
////        let resize = previewImage.resized(toWidth: 414.0)
//        print("AFTER ROTATE: \(getCurrentMillis())")
//        //print("AFTER performRotate: \(getCurrentMillis())")
//        if self.selectedScannerType == .qrcode {
//            let points = NSMutableArray()
//
//            let mat = Mat.init(uiImage: previewImage)
//            let result = WeChatQRCode().detectAndDecode(img: mat, points: points)
//            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
//            found(code: result.first ?? "empty")
////            print("AFTER ROTATE: \(getCurrentMillis())")
//        }
//        else{
//            print("###### previewImage IMAGE SIZE \(previewImage.size)")
//            let source: ZXLuminanceSource = ZXCGImageLuminanceSource(cgImage: img.cgImage)
//            let binazer = ZXHybridBinarizer(source: source)
//            let bitmap = ZXBinaryBitmap(binarizer: binazer)
//            print("###### BITMAP IMAGE WIDTH \(bitmap?.width)")
//
//            let reader = ZXMultiFormatReader()
//            let hints = ZXDecodeHints()
//            print("###### DECODE BITMAP",try? reader.decode(bitmap, hints: hints))
//            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
//            if let result = try? reader.decode(bitmap, hints: hints){
//                found(code: "Barcode Response\(result.text ?? "Empty ") BARCODE FORMAT \(result.barcodeFormat)")
////                print("AFTER ROTATE: \(getCurrentMillis())")
//            }
//
//        }
//        startCamera()
        
    }
}


