import Foundation

/// 이름을 붙여 저장하는 메트로놈 설정 프리셋입니다.
struct Preset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var settings: MetronomeSettings

    init(id: UUID = UUID(), name: String, settings: MetronomeSettings) {
        self.id = id
        self.name = name
        self.settings = settings
    }
}
