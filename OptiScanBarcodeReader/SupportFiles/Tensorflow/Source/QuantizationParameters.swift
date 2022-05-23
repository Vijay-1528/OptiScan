
/// Parameters that determine the mapping of quantized values to real values. Quantized values can
/// be mapped to float values using the following conversion:
/// `realValue = scale * (quantizedValue - zeroPoint)`.
public struct QuantizationParameters: Equatable, Hashable {
  /// The difference between real values corresponding to consecutive quantized values differing by
  /// 1. For example, the range of quantized values for `UInt8` data type is [0, 255].
  public let scale: Float

  /// The quantized value that corresponds to the real 0 value.
  public let zeroPoint: Int

  /// Creates a new instance with the given values.
  ///
  /// - Parameters:
  ///   - scale: The scale value for asymmetric quantization.
  ///   - zeroPoint: The zero point for asymmetric quantization.
  init(scale: Float, zeroPoint: Int) {
    self.scale = scale
    self.zeroPoint = zeroPoint
  }
}
