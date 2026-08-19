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

            tabBody { TrainerSectionView(state: state) }
                .tabItem { Label("연습", systemImage: "figure.run") }

            tabBody { DisplaySettingsView(state: state) }
                .tabItem { Label("표시", systemImage: "sun.max") }
        }
        .frame(width: Self.width)
        .background(Theme.Colors.bg)
        .preferredColorScheme(state.appearance.colorScheme)
    }

    /// 설정 창 폭입니다.
    static let width: CGFloat = 380

    /// 각 탭 콘텐츠에 공통 여백을 입힙니다.
    private func tabBody<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 클릭 음색 선택 패널입니다.
struct SoundSettingsView: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("클릭 음색")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut)
                Spacer()
                Picker("", selection: $state.sound) {
                    ForEach(ClickSound.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("클릭 음색")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.Colors.panel)
            }

            Text("볼륨은 본 창 하단에서 조절합니다.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.mut2)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsScreen(state: MetronomeState())
}
