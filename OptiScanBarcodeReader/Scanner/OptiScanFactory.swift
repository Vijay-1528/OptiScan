//
//  OptiScanFactory.swift
//  OptiScan
//
//  Created by MAC-OBS-25 on 11/01/22.
//

import UIKit

public class OptiScanFactory: NSObject {

    public static func createScanSession(scanView: UIView,events:ICameraScanCallback,scannerType:ScannerType) -> ICameraScan {
        return CameraScan(view: scanView,events: events, scannerType: scannerType)
     }
}
