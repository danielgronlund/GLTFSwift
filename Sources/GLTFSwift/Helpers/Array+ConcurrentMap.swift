import Foundation

extension Array {
  func concurrentMap<T>(_ transform: @escaping (Element) throws -> T?) throws -> [T] {
    let queue = DispatchQueue(label: "meshLoading", attributes: .concurrent)
    let group = DispatchGroup()

    var result = [T?](repeating: nil, count: self.count)
    var error: Error?

    for (index, element) in self.enumerated() {
      queue.async(group: group) {
        do {
          result[index] = try transform(element)
        } catch let e {
          error = e
        }
      }
    }

    group.wait()

    if let error = error {
      throw error
    }

    return result.compactMap { $0 }
  }
}
