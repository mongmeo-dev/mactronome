// metronome/View/SettingsScreen.swift
import SwiftUI

/// 설정 창(⌘,)입니다.
///
/// 사운드 음색 / 연습 도구 / 표시·창 설정을 본 창에서 분리했습니다.
/// 세 영역을 상시 노출하면 본 창 높이가 1,100pt 를 넘어
/// 13" 노트북에서 하단 시작 버튼이 화면 밖으로 밀려났고,
/// 창은 리사이즈도 스크롤도 되지 않아 접근 자체가 불가능했습니다.
struct SettingsScreen: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        TabView {
            SoundSettingsView(state: state)
                .tabItem { Label("사운드", systemImage: "speaker.wave.2") }

            TrainerSectionView(state: state)
                .tabItem { Label("연습", systemImage: "figure.run") }

            DisplaySettingsView(state: state)
                .tabItem { Label("표시", systemImage: "sun.max") }
        }
        // 탭마다 콘텐츠 양이 달라도 설정 창 크기가 튀지 않도록 고정합니다.
        .frame(width: Self.width, height: Self.height)
        .background(Theme.Colors.bg)
        .preferredColorScheme(state.appearance.colorScheme)
    }

    /// 설정 창 폭입니다.
    static let width: CGFloat = 420
    static let height: CGFloat = 360
}

/// 클릭 음색 선택 패널입니다.
struct SoundSettingsView: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        Form {
            Section {
                LabeledContent("클릭 음색") {
                    Picker("", selection: $state.sound) {
                        ForEach(ClickSound.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel("클릭 음색")
                }
            } header: {
                Text("클릭")
            } footer: {
                Text("볼륨은 메트로놈 창 하단에서 조절합니다.")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsScreen(state: MetronomeState())
}
