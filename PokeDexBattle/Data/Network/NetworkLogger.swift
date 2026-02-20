//
//  NetworkLogger.swift
//  PokeDexBattle — Data Layer
//
//  Lightweight console logger for HTTP requests and responses.
//  All methods are static so no instance is needed; the `enum` acts as a namespace.
//  Output is printed directly to stdout via `print()` which surfaces in the Xcode
//  console and in `xcrun simctl launch --console` terminal sessions.
//

import Foundation

/// Namespace for console-based HTTP logging.
/// Call `logRequest` before initiating a network call and either
/// `logResponse` or `logError` once it completes.
enum NetworkLogger {

    /// Prints a formatted request log entry to the console.
    /// Called immediately before each `URLSession.data(from:)` call.
    /// - Parameter url: The URL that is about to be fetched.
    static func logRequest(_ url: URL) {
        let timestamp = Self.timestamp()
        print("""
        ┌─────────────────────────────────────────────
        │ 📤 REQUEST  [\(timestamp)]
        │ URL: \(url.absoluteString)
        └─────────────────────────────────────────────
        """)
    }

    /// Prints a formatted response log entry with HTTP status, payload size, and round-trip time.
    /// Called after a successful `URLSession.data(from:)` call (even for non-2xx status codes).
    /// - Parameters:
    ///   - url: The URL that was fetched.
    ///   - statusCode: The HTTP status code from the response.
    ///   - byteCount: Number of bytes in the response body.
    ///   - duration: Elapsed time in seconds since the request was sent.
    static func logResponse(_ url: URL, statusCode: Int, byteCount: Int, duration: TimeInterval) {
        let timestamp = Self.timestamp()
        let icon = (200..<300).contains(statusCode) ? "✅" : "❌"
        print("""
        ┌─────────────────────────────────────────────
        │ 📥 RESPONSE \(icon) [\(timestamp)]
        │ URL: \(url.absoluteString)
        │ Status: \(statusCode)  |  Size: \(Self.formatBytes(byteCount))  |  Duration: \(String(format: "%.0f ms", duration * 1000))
        └─────────────────────────────────────────────
        """)
    }

    /// Prints a formatted error log entry when the network call itself fails
    /// (e.g. no connectivity, timeout, cancelled). Not called for HTTP error status codes
    /// because those are handled by `logResponse`.
    /// - Parameters:
    ///   - url: The URL that was being fetched when the error occurred.
    ///   - error: The Swift error thrown by `URLSession`.
    ///   - duration: Elapsed time in seconds before the failure.
    static func logError(_ url: URL, error: Error, duration: TimeInterval) {
        let timestamp = Self.timestamp()
        print("""
        ┌─────────────────────────────────────────────
        │ 📥 RESPONSE ❌ [\(timestamp)]
        │ URL: \(url.absoluteString)
        │ Error: \(error.localizedDescription)  |  Duration: \(String(format: "%.0f ms", duration * 1000))
        └─────────────────────────────────────────────
        """)
    }

    // MARK: - Private helpers

    /// Formats the current time as `HH:mm:ss.SSS` for log timestamps.
    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    /// Converts a raw byte count into a human-readable string (B / KB / MB).
    /// - Parameter bytes: Raw byte count from `Data.count`.
    private static func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1    { return "\(bytes) B" }
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.2f MB", kb / 1024)
    }
}
