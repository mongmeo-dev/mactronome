// metronome/View/PresetBarView.swift
import SwiftUI

/// 프리셋 저장/불러오기/삭제 바.
struct PresetBarView: View {
    @ObservedObject var state: MetronomeState

    @State private var showingSaveDialog = false
    @State private var showingOverwriteConfirm = false
    @State private var newPresetName = ""

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if state.presets.isEmpty {
                    Text("저장된 프리셋 없음")
                } else {
                    ForEach(state.presets) { preset in
                        Button {
                            state.applyPreset(preset)
                        } label: {
                            // 현재 설정과 일치하는 프리셋에 체크 표시를 답니다.
                            if preset.name == state.activePresetName {
                                Label(preset.name, systemImage: "checkmark")
                            } else {
                                Text(preset.name)
                            }
                        }
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
                    // 적용 중인 프리셋 이름을 노출합니다. 이름이 안 보이면
                    // 지금 설정이 어디서 온 것인지 알 방법이 없었습니다.
                    Text(state.activePresetName ?? "프리셋")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.Colors.ink)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(state.activePresetName.map { "프리셋 \($0) 적용 중" }
                                ?? "프리셋 불러오기")
            .help(state.activePresetName.map { "적용 중: \($0) — 클릭해 다른 프리셋 선택" }
                  ?? "저장한 프리셋 불러오기 / 삭제")

            // 저장된 설정에서 벗어났음을 알리는 표식입니다.
            if state.activePresetName == nil && !state.presets.isEmpty {
                Text("수정됨")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut2)
            }

            Spacer()

            Button {
                newPresetName = state.activePresetName ?? ""
                showingSaveDialog = true
            } label: {
                Text("현재 설정 저장")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.acc)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("현재 설정을 프리셋으로 저장")
            .help("현재 BPM·박자·강세·사운드·연습 설정을 이름 붙여 저장합니다")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
        .alert("프리셋 저장", isPresented: $showingSaveDialog) {
            TextField("이름", text: $newPresetName)
            Button("저장", action: requestSave)
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 BPM·박자·강세·사운드·연습 설정을 저장합니다.")
        }
        // 같은 이름이 있으면 말없이 덮어쓰던 동작을 확인 단계로 바꿉니다.
        .alert("같은 이름의 프리셋이 있습니다", isPresented: $showingOverwriteConfirm) {
            Button("덮어쓰기", role: .destructive) {
                state.saveCurrentAsPreset(named: newPresetName)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\"\(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines))\" 의 기존 내용이 현재 설정으로 바뀝니다.")
        }
    }

    /// 이름이 중복이면 확인을 받고, 아니면 바로 저장합니다.
    private func requestSave() {
        if state.presetExists(named: newPresetName) {
            showingOverwriteConfirm = true
        } else {
            state.saveCurrentAsPreset(named: newPresetName)
        }
    }
}
