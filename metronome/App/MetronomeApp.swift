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
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("재생") {
                Button(state.isPlaying ? "정지" : "시작") { state.togglePlay() }
                    .keyboardShortcut("p", modifiers: [.command])
                Divider()
                Button("BPM +1") { state.setBPM(state.bpm + 1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command])
                Button("BPM −1") { state.setBPM(state.bpm - 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command])
                Button("탬포 탭") { state.tap() }
                    .keyboardShortcut("t", modifiers: [.command])
            }
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
