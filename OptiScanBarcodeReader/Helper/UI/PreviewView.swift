//
//  PreviewView.swift
//  OptiScanBarcodeReader
//
//  Created by Dineshkumar Kandasamy on 17/05/22.
//

import Foundation
import UIKit
import AVFoundation

/**
 The camera frame is displayed on this view.
 */
public class PreviewView: UIView {
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Layer expected is of type VideoPreviewLayer")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return previewLayer.session
        }
        set {
            previewLayer.session = newValue
        }
    }
    
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

extension AVCaptureDevice {
    var isLocked: Bool {
        do {
            try lockForConfiguration()
            return true
        } catch {
            print(error)
            return false
        }
    }
    func setTorch(enable: Bool) {
       guard hasTorch && isLocked else { return }
        defer { unlockForConfiguration() }
        if enable {
            torchMode = .on
        } else {
            torchMode = .off
        }
    }
}


extension UIView{
    func addSubviews(_ views: UIView...) {
        views.forEach{ addSubview($0) }
    }
    
    func makeConstraints(top: NSLayoutYAxisAnchor?, left: NSLayoutXAxisAnchor?, right: NSLayoutXAxisAnchor?, bottom: NSLayoutYAxisAnchor?, topMargin: CGFloat, leftMargin: CGFloat, rightMargin: CGFloat, bottomMargin: CGFloat, width: CGFloat, height: CGFloat) {
        
        self.translatesAutoresizingMaskIntoConstraints = false
        if let top = top {
            self.topAnchor.constraint(equalTo: top, constant: topMargin).isActive = true
        }
        
        if let left = left {
            self.leftAnchor.constraint(equalTo: left, constant: leftMargin).isActive = true
        }
        
        if let right = right {
            self.rightAnchor.constraint(equalTo: right, constant: -rightMargin).isActive = true
        }
        
        if let bottom = bottom {
            self.bottomAnchor.constraint(equalTo: bottom, constant: -bottomMargin).isActive = true
        }
        
        if width != 0 {
            self.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        if height != 0 {
            self.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }
}
