import Foundation
import InsForge

enum InsForgeClientProvider {
    static let shared = InsForgeClient(
        baseURL: AppConstants.insForgeBaseURL,
        anonKey: AppConstants.insForgeAnonKey
    )
}
