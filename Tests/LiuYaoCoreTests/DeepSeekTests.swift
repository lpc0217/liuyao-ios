import XCTest
@testable import LiuYaoCore

final class DeepSeekTests: XCTestCase {
    func testExtractsCompletedAnswer() throws {
        let data = Data(#"{"choices":[{"message":{"content":"先稳住节奏。"},"finish_reason":"stop"}]}"#.utf8)
        XCTAssertEqual(try DeepSeekClient.decodeAnswer(data: data, statusCode: 200), "先稳住节奏。")
    }

    func testRejectsUnauthorizedEmptyAndTruncatedAnswers() {
        XCTAssertThrowsError(try DeepSeekClient.decodeAnswer(data: Data(), statusCode: 401))
        XCTAssertThrowsError(try DeepSeekClient.decodeAnswer(data: Data(#"{"choices":[]}"#.utf8), statusCode: 200))
        XCTAssertThrowsError(try DeepSeekClient.decodeAnswer(data: Data(#"{"choices":[{"message":{"content":"部分内容"},"finish_reason":"length"}]}"#.utf8), statusCode: 200))
    }

    func testRequestUsesOfficialEndpointAndKeepsQuestionInMessages() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-placeholder")
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            XCTAssertEqual(body?["model"] as? String, "deepseek-flash")
            let messages = body?["messages"] as? [[String: String]]
            XCTAssertEqual(messages?.last?["content"], "这次调动如何看待？")
            return Data(#"{"choices":[{"message":{"content":"结合实际条件判断。"},"finish_reason":"stop"}]}"#.utf8)
        }
        defer { StubProtocol.handler = nil }
        let client = DeepSeekClient(session: URLSession(configuration: config))
        let answer = try await client.interpret(apiKey: "test-placeholder", model: "deepseek-flash", messages: [ChatMessage(role: "user", content: "这次调动如何看待？")])
        XCTAssertEqual(answer, "结合实际条件判断。")
    }
}

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var copy = request
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(buffer, count: count)
                }
                copy.httpBody = data
            }
            let data = try Self.handler!(copy)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
