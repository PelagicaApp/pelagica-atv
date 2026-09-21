import Foundation
import Get
import JellyfinAPI

/// Decodes item responses without changing the generated SDK or unrelated enum validation.
nonisolated enum ItemResponseDecoder {
    enum Shape {
        case item, list, queryResult
    }

    // Match the SDK's two ISO date formats; its formatter initializer is internal.
    private static let fractionalDateFormatter = dateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ")
    private static let wholeDateFormatter = dateFormatter("yyyy-MM-dd'T'HH:mm:ssZZZZZ")

    private static func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = fractionalDateFormatter.date(from: value) ?? wholeDateFormatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an ISO 8601 date.")
            }
            return date
        }
        return decoder
    }()

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data, shape: Shape) throws -> Value {
        do {
            return try decoder.decode(type, from: data)
        } catch DecodingError.dataCorrupted(let context) where context.codingPath.last?.stringValue == "CollectionType" {
            // Jellyfin's response enum omits mixed although its collection options include it.
            // Ordinary responses take the SDK decoding path without a JSON round trip.
            let originalError = DecodingError.dataCorrupted(context)
            let json = try JSONSerialization.jsonObject(with: data)
            let normalized: Any
            switch shape {
            case .item:
                guard var item = json as? [String: Any], normalizeItem(&item) else { throw originalError }
                normalized = item
            case .list:
                guard var items = json as? [[String: Any]], normalizeItems(&items) else { throw originalError }
                normalized = items
            case .queryResult:
                guard var result = json as? [String: Any], var items = result["Items"] as? [[String: Any]],
                      normalizeItems(&items) else { throw originalError }
                result["Items"] = items
                normalized = result
            }
            return try decoder.decode(type, from: JSONSerialization.data(withJSONObject: normalized))
        }
    }

    private static func normalizeItems(_ items: inout [[String: Any]]) -> Bool {
        var changed = false
        for index in items.indices {
            if normalizeItem(&items[index]) { changed = true }
        }
        return changed
    }

    private static func normalizeItem(_ item: inout [String: Any]) -> Bool {
        var changed = false
        if item["CollectionType"] as? String == "mixed" {
            item["CollectionType"] = CollectionType.unknown.rawValue
            changed = true
        }
        // CurrentProgram is another BaseItemDto. Do not rewrite arbitrary metadata dictionaries.
        if var program = item["CurrentProgram"] as? [String: Any], normalizeItem(&program) {
            item["CurrentProgram"] = program
            changed = true
        }
        return changed
    }
}

extension JellyfinClient {
    nonisolated func sendItems(_ request: Request<BaseItemDto>) async throws -> Response<BaseItemDto> {
        try await itemResponse(request, shape: .item)
    }

    nonisolated func sendItems(_ request: Request<[BaseItemDto]>) async throws -> Response<[BaseItemDto]> {
        try await itemResponse(request, shape: .list)
    }

    nonisolated func sendItems(_ request: Request<BaseItemDtoQueryResult>) async throws -> Response<BaseItemDtoQueryResult> {
        try await itemResponse(request, shape: .queryResult)
    }

    private nonisolated func itemResponse<Value: Decodable & Sendable>(
        _ request: Request<Value>, shape: ItemResponseDecoder.Shape
    ) async throws -> Response<Value> {
        let response = try await data(for: request)
        return try response.map { try ItemResponseDecoder.decode(Value.self, from: $0, shape: shape) }
    }
}
