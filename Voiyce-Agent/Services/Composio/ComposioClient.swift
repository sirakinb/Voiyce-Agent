//
//  ComposioClient.swift
//  Voiyce-Agent
//

import Foundation

final class ComposioClient {
    private let baseURL = AppConstants.composioBaseURL
    private let session = URLSession.shared
    private let entityId = "default"

    // MARK: - Tools

    func getTools(apiKey: String, appNames: [String]? = nil) async throws -> [ComposioTool] {
        var urlString = "\(baseURL)/tools"
        if let apps = appNames, !apps.isEmpty {
            let appsParam = apps.joined(separator: ",")
            urlString += "?apps=\(appsParam)"
        }

        guard let url = URL(string: urlString) else {
            throw ComposioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let tools = try JSONDecoder().decode([ComposioTool].self, from: data)
        return tools
    }

    // MARK: - Tool Execution

    func executeTool(name: String, input: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/tools/execute") else {
            throw ComposioError.invalidURL
        }

        // Parse the input string to a dictionary
        let inputDict: [String: AnyCodable]
        if let data = input.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            inputDict = parsed.mapValues { AnyCodable($0) }
        } else {
            inputDict = [:]
        }

        let body = ComposioExecuteRequest(
            toolName: name,
            input: inputDict,
            entityId: entityId
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let result = try JSONDecoder().decode(ComposioExecuteResponse.self, from: data)

        if let error = result.error {
            throw ComposioError.executionFailed(error)
        }

        // Convert result data to string
        if let resultData = result.data {
            let jsonData = try JSONSerialization.data(withJSONObject: resultData.value, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "Success"
        }

        return "Success"
    }

    // MARK: - Connections

    func getConnections(apiKey: String) async throws -> [ComposioConnection] {
        guard let url = URL(string: "\(baseURL)/connections?entityId=\(entityId)") else {
            throw ComposioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode([ComposioConnection].self, from: data)
    }

    func initiateConnection(appName: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/connections") else {
            throw ComposioError.invalidURL
        }

        let body = ComposioConnectionRequest(
            appName: appName,
            entityId: entityId,
            redirectUrl: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let result = try JSONDecoder().decode(ComposioConnectionResponse.self, from: data)
        return result.redirectUrl ?? ""
    }

    // MARK: - Apps

    func getApps(apiKey: String) async throws -> [ComposioApp] {
        guard let url = URL(string: "\(baseURL)/apps") else {
            throw ComposioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode([ComposioApp].self, from: data)
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComposioError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ComposioError.httpError(httpResponse.statusCode)
        }
    }
}

enum ComposioError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case executionFailed(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .httpError(let code): return "HTTP error: \(code)"
        case .executionFailed(let msg): return "Tool execution failed: \(msg)"
        }
    }
}
