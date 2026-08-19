import XCTest
@testable import mactronome

final class AccentLevelTests: XCTestCase {
    func test_mute_hasZeroGain() {
        XCTAssertEqual(AccentLevel.mute.gain, 0)
    }
    func test_strong_louderThanWeak() {
        XCTAssertGreaterThan(AccentLevel.strong.gain, AccentLevel.weak.gain)
    }
    func test_rawValuesMatchDesign() {
        XCTAssertEqual(AccentLevel.mute.rawValue, 0)
        XCTAssertEqual(AccentLevel.weak.rawValue, 1)
        XCTAssertEqual(AccentLevel.medium.rawValue, 2)
        XCTAssertEqual(AccentLevel.strong.rawValue, 3)
    }

    /// 모든 레벨이 접근성 레이블/컨텍스트 메뉴용 이름을 가져야 합니다.
    func test_everyLevel_hasDisplayName() {
        for level in AccentLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty, "\(level) 표시 이름이 비었습니다")
        }
        XCTAssertEqual(Set(AccentLevel.allCases.map(\.displayName)).count,
                       AccentLevel.allCases.count,
                       "표시 이름이 중복되면 VoiceOver 로 구분할 수 없습니다")
    }
}
