import SwiftAnthropic
import Foundation

enum AgentToolDefinitions {

    /// Convert Composio tool schemas to Claude tool format
    static func convertComposioTools(_ composioTools: [ComposioTool]) -> [MessageParameter.Tool] {
        composioTools.compactMap { tool in
            convertTool(tool)
        }
    }

    private static func convertTool(_ tool: ComposioTool) -> MessageParameter.Tool? {
        var properties: [String: JSONSchema.Property] = [:]
        var required: [String] = []

        for param in tool.parameters {
            let property = JSONSchema.Property(
                type: mapType(param.type),
                description: param.description
            )
            properties[param.name] = property

            if param.required {
                required.append(param.name)
            }
        }

        let schema = JSONSchema(
            type: .object,
            properties: properties,
            required: required
        )

        return .function(
            name: tool.name,
            description: tool.description,
            inputSchema: schema
        )
    }

    private static func mapType(_ type: String) -> JSONSchema.JSONType {
        switch type.lowercased() {
        case "string": return .string
        case "integer", "int": return .integer
        case "number", "float", "double": return .number
        case "boolean", "bool": return .boolean
        case "array": return .array
        default: return .string
        }
    }
}
