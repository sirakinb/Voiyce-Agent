//
//  ComposioModels.swift
//  Voiyce-Agent
//

import Foundation

// MARK: - Tool Models

struct ComposioTool: Codable, Identifiable {
    nonisolated var id: String { name }
    let name: String
    let description: String
    let parameters: [ComposioToolParameter]
    let appName: String?

    enum CodingKeys: String, CodingKey {
        case name, description, parameters
        case appName = "app_name"
    }
}

struct ComposioToolParameter: Codable {
    let name: String
    let type: String
    let description: String
    let required: Bool
    let defaultValue: String?

    enum CodingKeys: String, CodingKey {
        case name, type, description, required
        case defaultValue = "default"
    }
}

// MARK: - Tool Execution

struct ComposioExecuteRequest: Codable {
    let toolName: String
    let input: [String: AnyCodable]
    let entityId: String

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case input
        case entityId = "entity_id"
    }
}

struct ComposioExecuteResponse: Codable {
    let success: Bool
    let data: AnyCodable?
    let error: String?
}

// MARK: - Connection Models

struct ComposioConnection: Codable, Identifiable {
    let id: String
    let appName: String
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case appName = "app_name"
        case status
        case createdAt = "created_at"
    }
}

struct ComposioConnectionRequest: Codable {
    let appName: String
    let entityId: String
    let redirectUrl: String?

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case entityId = "entity_id"
        case redirectUrl = "redirect_url"
    }
}

struct ComposioConnectionResponse: Codable {
    let connectionId: String?
    let redirectUrl: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id"
        case redirectUrl = "redirect_url"
        case status
    }
}

// MARK: - App Models

struct ComposioApp: Codable, Identifiable {
    nonisolated var id: String { name }
    let name: String
    let displayName: String?
    let description: String?
    let logo: String?
    let categories: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case description, logo, categories
    }
}

// MARK: - AnyCodable helper

struct AnyCodable: Codable {
    let value: Any

    nonisolated init(_ value: Any) {
        self.value = value
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
