import Foundation

public enum ImportError: Error, Sendable, Equatable {
    case missingAPIKey
    case http(status: Int, message: String)
    case invalidResponse
    case invalidJSON
}

/// ⚠️ TEMPORAIRE (ticket T-014, option A) : appel direct à l'API Anthropic avec une clé de développement
/// embarquée dans l'app de debug. Avant toute distribution, remplacer par l'Edge Function Supabase
/// `import-workout` (docs/architecture.md § 7) : la clé ne doit jamais être dans l'app publiée.
public struct AnthropicImportClient: Sendable {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let defaultModel = "claude-sonnet-5-5"

    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(apiKey: String, model: String = AnthropicImportClient.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func importWorkout(imageData: Data, mimeType: String, today: String) async throws -> WorkoutImportDTO {
        let request = try makeRequest(imageData: imageData, mimeType: mimeType, today: today)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ImportError.invalidResponse }
        return try Self.parseResponse(data, status: http.statusCode)
    }

    public func makeRequest(imageData: Data, mimeType: String, today: String) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw ImportError.missingAPIKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": mimeType,
                            "data": imageData.base64EncodedString(),
                        ],
                    ],
                    ["type": "text", "text": Self.prompt(today: today)],
                ],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func prompt(today: String) -> String {
        """
        Analyse cette image d'un workout fitness et extrais les informations. Réponds UNIQUEMENT avec un objet JSON valide, sans texte ni backticks, avec cette structure exacte:
        {
          "name": "nom du workout (si visible dans l'image, sinon 'WOD \(today)')",
          "format": "for_time" | "amrap" | "intervals",
          "cap_time": <secondes totales si AMRAP, sinon null>,
          "rounds": <nombre de rounds si intervals, sinon null>,
          "steps": [
            {
              "type": "reps" | "distance" | "time",
              "movement": "nom du mouvement",
              "value": <nombre>,
              "unit": "km" | "m" | "mi" | "s" | "min" | null,
              "weight": <kg si précisé, sinon null>,
              "notes": "infos supplémentaires si utile, sinon null"
            }
          ]
        }
        Règles:
        - format "for_time" si c'est une séquence à finir le plus vite possible
        - format "amrap" si il y a un time cap et l'objectif est max rounds
        - format "intervals" si il y a des répétitions de work/rest/rounds
        - Pour les reps: type="reps", pas d'unit
        - Pour les distances: type="distance", unit="km" ou "m" ou "mi"
        - Pour les temps: type="time", unit="s" ou "min"
        - Si un cap time est indiqué (ex: "12 min AMRAP"), cap_time = 720
        - Ne mets jamais de commentaires dans le JSON
        """
    }

    /// Extrait la séance de la réponse de l'API (texte JSON, éventuellement entouré de ```).
    public static func parseResponse(_ data: Data, status: Int) throws -> WorkoutImportDTO {
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message ?? "HTTP \(status)"
            throw ImportError.http(status: status, message: message)
        }
        guard let envelope = try? JSONDecoder().decode(MessageEnvelope.self, from: data),
              let text = envelope.content.first(where: { $0.type == "text" })?.text else {
            throw ImportError.invalidResponse
        }
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let json = cleaned.data(using: .utf8),
              let dto = try? JSONDecoder().decode(WorkoutImportDTO.self, from: json) else {
            throw ImportError.invalidJSON
        }
        return dto
    }

    private struct MessageEnvelope: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
    }

    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}
