

import TensorFlowLiteC

/// A TensorFlow Lite model used by the `Interpreter` to perform inference.
final class Model {
  /// The `TfLiteModel` C pointer type represented as an `UnsafePointer<TfLiteModel>`.
  typealias CModel = OpaquePointer

  /// The underlying `TfLiteModel` C pointer.
  let cModel: CModel?

  /// Creates a new instance with the given `filePath`.
  ///
  /// - Precondition: Initialization can fail if the given `filePath` is invalid.
  /// - Parameters:
  ///   - filePath: The local file path to a TensorFlow Lite model.
  init?(filePath: String) {
    guard !filePath.isEmpty, let cModel = TfLiteModelCreateFromFile(filePath) else { return nil }
    self.cModel = cModel
  }

  deinit {
    TfLiteModelDelete(cModel)
  }
}
