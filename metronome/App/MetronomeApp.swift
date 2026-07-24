// metronome/App/MetronomeApp.swift
import SwiftUI

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
    }
}
