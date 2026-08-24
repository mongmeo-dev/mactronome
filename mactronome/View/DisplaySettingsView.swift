// metronome/View/DisplaySettingsView.swift
import SwiftUI

/// 표시/창 설정: 비주얼 플래시, 화면 모드, 항상 위에.
struct DisplaySettingsView: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        Form {
            Section {
                Toggle("비주얼 플래시", isOn: $state.visualFlash)
                    .toggleStyle(.switch)
                    .tint(Theme.Colors.acc)
            } header: {
                Text("박자 표시")
            } footer: {
                Text("강박에서 창 전체를 짧게 밝혀 소리를 듣기 어려운 상황에서도 박자를 보여줍니다.")
            }

            Section("외관") {
                LabeledContent("화면 모드") {
                    Picker("", selection: $state.appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .accessibilityLabel("화면 모드")
                }
            }

            Section("창") {
                Toggle("항상 위에", isOn: $state.floating)
                    .toggleStyle(.switch)
                    .tint(Theme.Colors.acc)
            }
        }
        .formStyle(.grouped)
    }
}
