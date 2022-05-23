//
//  ICameraScan.swift
//  OptiScan
//
//  Created by MAC-OBS-25 on 11/01/22.
//

import Foundation
import UIKit
/// * ICameraScan is the functional interface for camera scan.
/// * Application will use this interface to access camera scan methods in  application.

 public protocol ICameraScan{
        
    ///  * This method is used to enable or disable torch.
     func enableTorch(enable:Bool)
     
     ///  * This method is used to chck whether torch enabled or not
     ///  * @return Boolean which is true if it is enabled otherwise false
     func isTorchEnabled() -> Bool
     
     ///  * This method is used to get the scanner view
     ///  * @return UIView which is contain scanner object view
     func optiscanView() -> UIView
     
     ///  * This method is used to enable or disable rectangle scanner box.
     func enableScannerBox(enable:Bool)
     
     /// This method is used to release the running camera preview.
     func destroy()
    
}


/// * Callback interface for getting progress & error event from camera scan
/// * ICameraScanCallback user MUST implement this interface to get callback from scanner end.

 public protocol ICameraScanCallback {
    
    /// * This callback method is triggered once playback state changed in player.
    /// - Parameter playbackState: @param playbackState - which is represent the changed playback state.
    func onScanningSucceed(_ str: String?)

    /// * This callback method is triggered once any error occurred during the scanner session.
    /// - Parameters:
    /// - message: description of error
    func onScanningDidFail(errorMessage: String)
     
    /// * This callback method is triggered once scanner session stopped.
    func onScanningDidStop()

}

public enum ScannerType {
    case qrcode
    case barcode
    case any
}
