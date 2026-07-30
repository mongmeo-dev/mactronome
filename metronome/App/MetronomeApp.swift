// metronome/App/MetronomeApp.swift
import SwiftUI
import AppKit

@main
struct MetronomeApp: App {
    /// 앱 전역 상태의 단일 소유자입니다. 설정은 UserDefaults에 영속됩니다.
    @StateObject private var state = MetronomeState(store: .standard)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
        // 커스텀 타이틀바를 직접 그리므로 시스템 타이틀바는 숨깁니다.
        // (신호등 버튼은 hiddenTitleBar 에서도 그대로 남아 좌상단에 겹쳐 표시됩니다.)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("재생") {
                Button(state.isPlaying ? "정지" : "시작") { state.togglePlay() }
                    .keyboardShortcut("p", modifiers: [.command])
                Divider()
                // 창 안의 방향키(↑↓ ±10, ←→ ±1)와 증감폭을 일치시킵니다.
                // 이전에는 ⌘↑ 가 +1 이라 창 안 ↑(+10)와 어긋났습니다.
                Button("BPM +10") { state.setBPM(state.bpm + 10) }
                    .keyboardShortcut(.upArrow, modifiers: [.command])
                Button("BPM −10") { state.setBPM(state.bpm - 10) }
                    .keyboardShortcut(.downArrow, modifiers: [.command])
                Button("BPM +1") { state.setBPM(state.bpm + 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                Button("BPM −1") { state.setBPM(state.bpm - 1) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("템포 탭") { state.tap() }
                    .keyboardShortcut("t", modifiers: [.command])
                Divider()
                Button(state.compact ? "일반 모드" : "컴팩트 모드") { state.compact.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        // 사운드 음색 / 연습 도구 / 표시·창 설정은 표준 설정 창(⌘,)으로 분리합니다.
        Settings {
            SettingsScreen(state: state)
        }

        // 메뉴바에서 재생/정지·BPM을 빠르게 제어합니다.
        MenuBarExtra {
            MenuBarContent(state: state)
        } label: {
            Image(systemName: state.isPlaying ? "pause.circle.fill" : "metronome")
        }
    }
}

/// 메뉴바 팝오버의 간단한 제어 항목입니다.
private struct MenuBarContent: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        Button(state.isPlaying ? "정지" : "시작") { state.togglePlay() }
        Text("BPM \(Int(state.bpm))")
        Button("BPM +5") { state.setBPM(state.bpm + 5) }
        Button("BPM −5") { state.setBPM(state.bpm - 5) }
        Divider()
        Button("종료") { NSApplication.shared.terminate(nil) }
    }
}
