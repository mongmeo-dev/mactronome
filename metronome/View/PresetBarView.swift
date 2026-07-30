// metronome/View/PresetBarView.swift
import SwiftUI

/// 프리셋 저장/불러오기/삭제 바.
struct PresetBarView: View {
    @ObservedObject var state: MetronomeState

    @State private var showingSaveDialog = false
    @State private var newPresetName = ""

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if state.presets.isEmpty {
                    Text("저장된 프리셋 없음")
                } else {
                    ForEach(state.presets) { preset in
                        Button(preset.name) { state.applyPreset(preset) }
                    }
                    Divider()
                    Menu("삭제") {
                        ForEach(state.presets) { preset in
                            Button(role: .destructive) {
                                state.deletePreset(preset)
                            } label: {
                                Text(preset.name)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11))
                    Text("프리셋")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.Colors.ink)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("프리셋 불러오기")

            Spacer()

            Button {
                newPresetName = ""
                showingSaveDialog = true
            } label: {
                Text("현재 설정 저장")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.acc)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("현재 설정을 프리셋으로 저장")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
        .alert("프리셋 저장", isPresented: $showingSaveDialog) {
            TextField("이름", text: $newPresetName)
            Button("저장") { state.saveCurrentAsPreset(named: newPresetName) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 BPM·박자·강세·사운드·연습 설정을 저장합니다.")
        }
    }
}
