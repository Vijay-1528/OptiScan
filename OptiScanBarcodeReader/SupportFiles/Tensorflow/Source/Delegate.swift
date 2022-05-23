

import TensorFlowLiteC

/// A delegate that the `Interpreter` uses to perform TensorFlow Lite model computations.
public protocol Delegate: AnyObject {
  /// The `TfLiteDelegate` C pointer type.
  typealias CDelegate = UnsafeMutablePointer<TfLiteDelegate>

  /// The delegate that performs model computations.
  var cDelegate: CDelegate { get }
}
