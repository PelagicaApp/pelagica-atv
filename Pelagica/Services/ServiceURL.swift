//
//  ServiceURL.swift
//  Pelagica
//

import Foundation

nonisolated enum ServiceURL {
    /// Parses a user-configured service address, tolerating a missing scheme (defaults to https) or a malformed one like `https:/host`.
    static func components(from string: String) -> URLComponents? {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = value.firstMatch(of: #/^(https?):/*/#.ignoresCase()) {
            value = "\(match.1.lowercased())://" + value[match.range.upperBound...]
        } else if !value.contains("://") {
            value = "https://" + value
        }
        guard let components = URLComponents(string: value), components.host?.isEmpty == false else { return nil }
        return components
    }
}
