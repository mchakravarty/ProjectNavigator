//
//  WrappedUUIDSet.swift
//  HaskellApp
//
//  Created by Manuel M T Chakravarty on 14/11/2021.
//

import Foundation


public struct WrappedUUIDSet {

  public var ids: Set<UUID> = []

  public subscript(id: UUID) -> Bool {
    get { ids.contains(id) }
    set { 
      if newValue { ids.insert(id) } else { ids.remove(id) }
    }
  }
}

extension WrappedUUIDSet: RawRepresentable {

  public init?(rawValue: String) {
    ids = Set(rawValue.components(separatedBy: ",").compactMap{ UUID(uuidString: $0) })
  }

  public var rawValue: String { ids.map({ $0.uuidString }).joined(separator: ",") }
}
