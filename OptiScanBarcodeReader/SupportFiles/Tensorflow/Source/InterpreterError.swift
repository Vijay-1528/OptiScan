

import Foundation

/// Errors thrown by the TensorFlow Lite `Interpreter`.
public enum InterpreterError: Error, Equatable, Hashable {
  case invalidTensorIndex(index: Int, maxIndex: Int)
  case invalidTensorDataCount(provided: Int, required: Int)
  case invalidTensorDataType
  case failedToLoadModel
  case failedToCreateInterpreter
  case failedToResizeInputTensor(index: Int)
  case failedToCopyDataToInputTensor
  case failedToAllocateTensors
  case allocateTensorsRequired
  case invokeInterpreterRequired
  case tensorFlowLiteError(String)
}

extension InterpreterError: LocalizedError {
  /// A localized description of the interpreter error.
  public var errorDescription: String? {
    switch self {
    case .invalidTensorIndex(let index, let maxIndex):
      return "Invalid tensor index \(index), max index is \(maxIndex)."
    case .invalidTensorDataCount(let provided, let required):
      return "Provided data count \(provided) must match the required count \(required)."
    case .invalidTensorDataType:
      return "Tensor data type is unsupported or could not be determined due to a model error."
    case .failedToLoadModel:
      return "Failed to load the given model."
    case .failedToCreateInterpreter:
      return "Failed to create the interpreter."
    case .failedToResizeInputTensor(let index):
      return "Failed to resize input tensor at index \(index)."
    case .failedToCopyDataToInputTensor:
      return "Failed to copy data to input tensor."
    case .failedToAllocateTensors:
      return "Failed to allocate memory for input tensors."
    case .allocateTensorsRequired:
      return "Must call allocateTensors()."
    case .invokeInterpreterRequired:
      return "Must call invoke()."
    case .tensorFlowLiteError(let message):
      return "TensorFlow Lite Error: \(message)"
    }
  }
}

extension InterpreterError: CustomStringConvertible {
  /// A textual representation of the TensorFlow Lite interpreter error.
  public var description: String { return errorDescription ?? "Unknown error." }
}
