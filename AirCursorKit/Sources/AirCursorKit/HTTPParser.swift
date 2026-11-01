import Foundation

/// Minimal HTTP/1.1 request, enough for the Mac's local server.
public struct HTTPRequest: Sendable, Equatable {
    public var method: String
    public var path: String
    /// Header names are lowercased.
    public var headers: [String: String]
    public var body: Data

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}

public enum HTTPParseError: Error, Equatable {
    case malformed
    case tooLarge
}

public enum HTTPParser {
    public static let maxHeaderBytes = 8 * 1024
    public static let maxBodyBytes = 64 * 1024

    private static let headerTerminator = Data("\r\n\r\n".utf8)

    /// Parses one request from the front of `buffer`.
    /// - Returns: the request and the number of bytes it used, or nil if more data is needed.
    public static func parse(_ buffer: Data) throws -> (request: HTTPRequest, consumed: Int)? {
        guard let headerEnd = buffer.range(of: headerTerminator) else {
            if buffer.count > maxHeaderBytes { throw HTTPParseError.tooLarge }
            return nil
        }
        let headerData = buffer[buffer.startIndex..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw HTTPParseError.malformed
        }

        var lines = headerText.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else {
            throw HTTPParseError.malformed
        }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { throw HTTPParseError.malformed }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0 else { throw HTTPParseError.malformed }
        guard length <= maxBodyBytes else { throw HTTPParseError.tooLarge }

        let bodyStart = headerEnd.upperBound
        guard buffer.endIndex - bodyStart >= length else { return nil }
        let body = Data(buffer[bodyStart..<(bodyStart + length)])

        let request = HTTPRequest(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: body
        )
        return (request, bodyStart + length - buffer.startIndex)
    }

    public static func response(status: Int, reason: String, body: Data = Data(), contentType: String? = nil) -> Data {
        var head = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: \(body.count)\r\nConnection: keep-alive\r\n"
        if let contentType {
            head += "Content-Type: \(contentType)\r\n"
        }
        head += "\r\n"
        return Data(head.utf8) + body
    }
}
