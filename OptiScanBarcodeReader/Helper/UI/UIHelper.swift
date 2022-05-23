//
//  UIHelper.swift
//  OptiScanBarcodeReader
//
//  Created by Dineshkumar Kandasamy on 17/05/22.
//

import Foundation
import UIKit

extension String {

  /**This method gets size of a string with a particular font.
   */
  func size(usingFont font: UIFont) -> CGSize {
    return size(withAttributes: [.font: font])
  }

}

public struct KD {
    
    public static let SCREEN_WIDTH = UIScreen.main.bounds.width
    public static let SCREEN_HEIGHT = UIScreen.main.bounds.size.height
    
}

extension UIViewController {
    
    func showToast(message : String, seconds: Double){
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.view.backgroundColor = .black
        alert.view.alpha = 0.5
        alert.view.layer.cornerRadius = 15
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            alert.dismiss(animated: true)
        }
    }
}

extension UIDevice {
//    public func hasNotch() -> Bool {
//        let bottom = UIApplication.shared.connectedScenes.filter({$0.activationState == .foregroundActive}).compactMap({$0 as? UIWindowScene}).first?.windows.filter({$0.isKeyWindow}).first?.safeAreaInsets.bottom ?? 0
//        return bottom > 0
//    }
}



extension CGImage {
    var brightnessValue: Int {
        get {
            guard let imageData = self.dataProvider?.data else { return 0 }
            guard let ptr = CFDataGetBytePtr(imageData) else { return 0 }
            let length = CFDataGetLength(imageData)
            
            var R = 0
            var G = 0
            var B = 0
            var n = 0
            
            for i in stride(from: 0, to: length, by: 4) {
                
                R += Int(ptr[i])
                G += Int(ptr[i + 1])
                B += Int(ptr[i + 2])
                n += 1
                
            }
            
            let res = (R + B + G) / (n * 3)
            print(res)
            return res
        }
    }
}
