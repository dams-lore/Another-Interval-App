import Foundation
import Testing
import Backend

@Suite struct BackendTests {
    @Test func moduleNameIsStable() {
        #expect(Backend.moduleName == "Backend")
    }
}

@Suite struct AnthropicImportClientTests {
    private func envelope(text: String) -> Data {
        let body: [String: Any] = ["content": [["type": "text", "text": text]]]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    private let json = #"{"name":"Fran","format":"for_time","cap_time":null,"rounds":null,"steps":[{"type":"reps","movement":"Thrusters","value":21,"unit":null,"weight":43,"notes":null}]}"#

    @Test func requestTargetsTheMessagesAPI() throws {
        let client = AnthropicImportClient(apiKey: "test-key")
        let request = try client.makeRequest(imageData: Data([1, 2, 3]), mimeType: "image/jpeg", today: "21/11/2026")
        #expect(request.url == AnthropicImportClient.endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let body = try #require(request.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == "claude-sonnet-5-5")
        // On relit le JSON décodé : le texte brut échappe les « / » (21\/11\/2026).
        let messages = try #require(object["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? [[String: Any]])
        let image = try #require(content.first?["source"] as? [String: Any])
        #expect(image["data"] as? String == Data([1, 2, 3]).base64EncodedString())
        let prompt = try #require(content.last?["text"] as? String)
        #expect(prompt.contains("21/11/2026"))
    }

    @Test func promptKnowsEveryXFormats() {
        let prompt = AnthropicImportClient.prompt(today: "21/11/2026")
        #expect(prompt.contains("interval_seconds"))
        #expect(prompt.contains("Every 5:00 x 6 sets"))
        #expect(prompt.contains("calories"))
    }

    @Test func parsesAnEveryXWorkout() throws {
        let emom = #"{"name":"EMF RX - DARK ZONE","format":"emom","cap_time":null,"rounds":6,"interval_seconds":300,"steps":[{"type":"reps","movement":"Row","value":20,"unit":"cal","weight":null,"notes":"H/F : 20/16"},{"type":"reps","movement":"Burpees Over Row","value":15,"unit":null,"weight":null,"notes":null}]}"#
        let dto = try AnthropicImportClient.parseResponse(envelope(text: emom), status: 200)
        #expect(dto.format == "emom")
        #expect(dto.rounds == 6)
        #expect(dto.intervalSeconds == 300)
        #expect(dto.steps.count == 2)
    }

    @Test func missingKeyIsRejectedBeforeAnyNetworkCall() {
        let client = AnthropicImportClient(apiKey: "")
        #expect(throws: ImportError.missingAPIKey) {
            try client.makeRequest(imageData: Data(), mimeType: "image/jpeg", today: "x")
        }
    }

    @Test func parsesPlainJSON() throws {
        let dto = try AnthropicImportClient.parseResponse(envelope(text: json), status: 200)
        #expect(dto.name == "Fran")
        #expect(dto.format == "for_time")
        #expect(dto.steps.first?.weight == 43)
    }

    @Test func parsesJSONWrappedInCodeFences() throws {
        let dto = try AnthropicImportClient.parseResponse(envelope(text: "```json\n\(json)\n```"), status: 200)
        #expect(dto.steps.count == 1)
    }

    @Test func httpErrorKeepsTheAPIMessage() {
        let error = #"{"error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        #expect(throws: ImportError.http(status: 401, message: "invalid x-api-key")) {
            try AnthropicImportClient.parseResponse(Data(error.utf8), status: 401)
        }
    }

    @Test func garbageTextIsAnInvalidJSONError() {
        #expect(throws: ImportError.invalidJSON) {
            try AnthropicImportClient.parseResponse(envelope(text: "Je ne vois pas de séance."), status: 200)
        }
    }

    @Test func nonMessageBodyIsAnInvalidResponse() {
        #expect(throws: ImportError.invalidResponse) {
            try AnthropicImportClient.parseResponse(Data("{}".utf8), status: 200)
        }
    }
}
