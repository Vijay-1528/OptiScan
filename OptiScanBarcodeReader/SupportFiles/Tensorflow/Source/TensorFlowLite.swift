
import TensorFlowLiteC

/// TensorFlow Lite runtime values.
public enum Runtime {
  /// A string describing the semantic versioning information for the runtime. Is an empty string if
  /// the version could not be determined.
  public static var version: String { return TfLiteVersion().map(String.init) ?? "" }
}
