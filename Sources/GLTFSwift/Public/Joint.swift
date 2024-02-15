import Foundation
import simd

public class Joint {
  public let index: Int
  public let inverseBindMatrix: simd_float4x4
  public let name: String?

  init(index: Int, inverseBindMatrix: simd_float4x4, name: String?) {
    self.index = index
    self.inverseBindMatrix = inverseBindMatrix
    self.name = name
  }
}
