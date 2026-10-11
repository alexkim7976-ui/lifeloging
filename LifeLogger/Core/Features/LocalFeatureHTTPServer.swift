import Foundation
import Network
import SwiftData

enum LocalFeatureHTTPServer {
    nonisolated(unsafe) private static var listener: NWListener?
    nonisolated(unsafe) private static var modelContext: ModelContext?
    private static let queue = DispatchQueue(label: "com.lifelogger.localapi", qos: .userInitiated)

    @MainActor
    static func start(modelContext: ModelContext?) throws {
        Self.modelContext = modelContext
        guard listener == nil else { return }

        let port = NWEndpoint.Port(rawValue: 8765)!
        listener = try NWListener(using: .tcp, on: port)
        listener?.newConnectionHandler = { connection in
            accept(connection)
        }
        listener?.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                AppLogger.persistence.error("Local API failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        listener?.start(queue: queue)
    }

    @MainActor
    static func stop() {
        listener?.cancel()
        listener = nil
    }

    private static func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, _ in
            guard let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let path = parsePath(from: request)
            Task { @MainActor in
                let body = responseBody(for: path)
                let response = httpResponse(status: 200, body: body, contentType: "application/json; charset=utf-8")
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    @MainActor
    private static func responseBody(for path: String) -> String {
        switch path {
        case "/", "/health":
            return #"{"ok":true,"service":"LifeLogger"}"#
        case "/stats", "/stats/today":
            return LocalFeatureAPI.jsonSnapshot(modelContext: modelContext)
        case "/tag":
            let tag = FeatureMetricsStore.string("context.currentTag")
            return #"{"tag":"\#(tag.replacingOccurrences(of: "\"", with: "\\\""))"}"#
        case "/focus-session/start":
            FocusSessionStore.start()
            return #"{"focusSession":true}"#
        case "/focus-session/stop":
            FocusSessionStore.stop()
            return #"{"focusSession":false}"#
        default:
            return #"{"error":"not_found","path":"\#(path)"}"#
        }
    }

    private static func parsePath(from request: String) -> String {
        let firstLine = request.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? request
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return "/" }
        let raw = String(parts[1])
        return raw.split(separator: "?").first.map(String.init) ?? raw
    }

    private static func httpResponse(status: Int, body: String, contentType: String) -> String {
        """
        HTTP/1.1 \(status) OK\r
        Content-Type: \(contentType)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        Content-Length: \(body.utf8.count)\r
        \r
        \(body)
        """
    }
}
