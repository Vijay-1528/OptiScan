//
//  Upscale.swift
//  OptiScanBarcodeReader
//
//  Created by MAC-OBS-25 on 28/03/22.
//

import Foundation
import opencv2

extension UIImage{
    
    func upscaleBarcode() -> UIImage {
        let srcImg = Mat(uiImage: self)
        let dstImg = Mat()
        Imgproc.resize(src: srcImg, dst: dstImg, dsize: Size2i(width: Int32(self.size.width) * Int32(1.5), height: Int32(self.size.height) * Int32(1.5)))
        return dstImg.toUIImage()
    }
    
    func upscaleQRcode() -> UIImage {
        let srcImg = Mat(uiImage: self)
        let dstImg = Mat()
        Imgproc.resize(src: srcImg, dst: dstImg, dsize: Size2i(width: Int32(self.size.width) * 2, height: Int32(self.size.height) * 2))
        return dstImg.toUIImage()
    }
}
