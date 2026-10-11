import Foundation
import SwiftData

struct EnrichedActivitySample: Sendable {
    let appName: String
    let bundleID: String
    let windowTitle: String
    let category: ActivityCategory
    let timestamp: Date
    let monitorName: String
    let spaceIndex: Int
    let isFullScreen: Bool
    let projectTag: String?
    let browserDomain: String?
    let documentName: String?
    let terminalCWD: String?
    let windowCount: Int
}

struct MacFeatureLiveState: Sendable, Identifiable {
    let id: String
    let value: String
    let detail: String?
    let isActive: Bool
    let updatedAt: Date
}

struct MacFeatureActionResult: Sendable {
    let message: String
    let success: Bool
}

@MainActor
protocol MacFeatureCategoryEngine: Sendable {
    static var categoryId: String { get }
    static func activate()
    static func processSample(_ sample: EnrichedActivitySample)
    static func liveState(for featureId: String, modelContext: ModelContext?) -> MacFeatureLiveState
    static func perform(featureId: String, modelContext: ModelContext?) -> MacFeatureActionResult?
}