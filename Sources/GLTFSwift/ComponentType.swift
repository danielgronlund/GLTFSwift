import Foundation
import simd

public enum ComponentType: Int, Decodable {
  case byte = 5120
  case unsignedByte = 5121
  case short = 5122
  case unsignedShort = 5123
  case unsignedInt = 5125
  case float = 5126

  public var size: Int {
    switch self {
    case .byte: 1
    case .unsignedByte: 1
    case .short: 2
    case .unsignedShort: 2
    case .unsignedInt: 4
    case .float: 4
    }
  }
}

public enum DataType: String, Decodable {
  case scalar = "SCALAR"
  case vec2 = "VEC2"
  case vec3 = "VEC3"
  case vec4 = "VEC4"
  case mat2 = "MAT2"
  case mat3 = "MAT3"
  case mat4 = "MAT4"

  public var numberOfComponents: Int {
    switch self {
    case .scalar: 1
    case .vec2: 2
    case .vec3: 3
    case .vec4: 4
    case .mat2: 4
    case .mat3: 9
    case .mat4: 16
    }
  }
}

public struct BufferTypeDescriptor {
  public let componentType: ComponentType
  public let dataType: DataType

  public var totalSize: Int {
    componentType.size * dataType.numberOfComponents
  }

  init(componentType: ComponentType, dataType: DataType) {
    self.componentType = componentType
    self.dataType = dataType
  }
}
