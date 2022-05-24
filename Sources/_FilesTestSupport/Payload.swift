//
//  Payload.swift
//  
//
//  Created by Manuel M T Chakravarty on 10/05/2022.
//

import Foundation

import Files


public struct Payload: FileContents {
  public var text: String

  public init(text: String) {
    self.text = text
  }

  public init(name: String, data: Data) throws {
    guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.formatting) }
    self.text = text
  }

  public func data() throws -> Data {
    guard let data = text.data(using: .utf8) else { throw CocoaError(.formatting) }
    return data
  }

  public mutating func flush() throws { }
}

public func treeToPayload(tree: [String: Any]) throws -> [String: Any] {
  try tree.mapValues{ value in
    if let text = value as? String { return Payload(text: text) }
    else if let tree = value as? [String: Any] { return try treeToPayload(tree: tree) }
    else { throw CocoaError(.formatting) }
  }
}
