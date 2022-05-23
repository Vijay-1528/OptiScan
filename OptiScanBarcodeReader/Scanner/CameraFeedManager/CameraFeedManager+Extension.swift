//
//  CameraFeedManager+Extension.swift
//  OptiScanBarcodeReader
//
//  Created by Dineshkumar Kandasamy on 18/05/22.
//

import Foundation


// MARK: CameraFeedManagerDelegate Declaration

public protocol CameraFeedManagerDelegate: AnyObject {
    
    /**
     This method delivers the pixel buffer of the current frame seen by the device's camera.
     */
    func didOutput(pixelBuffer: CVPixelBuffer)
    
    /**
     This method intimates that the camera permissions have been denied.
     */
    func presentCameraPermissionsDeniedAlert()
    
    /**
     This method intimates that there was an error in video configuration.
     */
    func presentVideoConfigurationErrorAlert()
    
    /**
     This method intimates that a session runtime error occurred.
     */
    func sessionRunTimeErrorOccurred()
    
    /**
     This method intimates that the session was interrupted.
     */
    func sessionWasInterrupted(canResumeManually resumeManually: Bool)
    
    /**
     This method intimates that the session interruption has ended.
     */
    func sessionInterruptionEnded()
    
    
    func outputData(str: String, codeType: String)
    
}

/**
 This enum holds the state of the camera initialization.
 */
public enum CameraConfiguration {
    case success
    case failed
    case permissionDenied
}

extension CameraFeedManager {
    
    /**
     This method stops a running an AVCaptureSession.
     */
    public func stopSession() {
        self.removeObservers()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
    }
    
    // MARK: Session Start and End methods
    
    /**
     This method starts an AVCaptureSession based on whether the camera configuration was successful.
     */
    public func checkCameraConfigurationAndStartSession() {
        sessionQueue.async {
            switch self.cameraConfiguration {
            case .success:
                self.addObservers()
                self.startSession()
                
            case .failed:
                DispatchQueue.main.async {
                    self.delegate?.presentVideoConfigurationErrorAlert()
                }
                
            case .permissionDenied:
                DispatchQueue.main.async {
                    self.delegate?.presentCameraPermissionsDeniedAlert()
                }
                
            }
        }
    }
    
}

public enum FUNTIONTYPE: String {
    
    case updateCameraScale = "CAMFEED: UPDATE-CAMERA-SCALE"
    case processResults = "PROCESS-RESULTS"

    case captureOutput = "CAPTURE-OUTPUT"
    case drawRect = "DRAW-RECT"
    case imageSaved = "IMAGE-SAVED"
    case formatResults = "FORMAT-RESULTS"
    case calculateBoundBox = "CALCULATE-BOUND-BOX"
    case longDistance = "LONG-DISTANCE"
    case rotateImage = "ROTATE-IMAGE"
    case drawAfterCalculation = "DRAW-AFTER-CALCULATION"
    
    case runModel = "YOLO: RUN-MODEL"
    case imageSavedYolo = "YOLO: IMAGE-SAVED"
    case initializeModel = "YOLO: INITIALIZE-MODEL"
    case originalCropRect = "YOLO: ORIGINAL-CROP-RECT"
    case rgbDataFromBuffer = "YOLO: RGB-DATA-FROM-BUFFER"

}
