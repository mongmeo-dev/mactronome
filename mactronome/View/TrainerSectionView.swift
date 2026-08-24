// metronome/View/TrainerSectionView.swift
import SwiftUI

/// 연습 도구 패널: 템포 트레이너(자동 가속)와 카운트인 설정.
struct TrainerSectionView: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        Form {
            Section("자동 가속") {
                Toggle("자동 가속 사용", isOn: $state.trainerEnabled)
                    .toggleStyle(.switch)
                    .tint(Theme.Colors.acc)

                if state.trainerEnabled {
                    labeledStepper(
                        "변경 주기",
                        value: $state.trainerEveryBars,
                        range: 1...32,
                        suffix: "마디"
                    )
                    labeledStepper(
                        "변경 폭",
                        value: $state.trainerBPMStep,
                        range: 1...30,
                        suffix: "BPM"
                    )
                    labeledStepper(
                        "목표",
                        value: $state.trainerTargetBPM,
                        range: Int(MetronomeState.bpmRange.lowerBound)...Int(MetronomeState.bpmRange.upperBound),
                        suffix: "BPM"
                    )

                    Text("\(state.trainerEveryBars)마디마다 \(state.trainerBPMStep) BPM씩 올려 \(state.trainerTargetBPM) BPM까지 연습합니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.mut)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }

            Section("시작") {
                labeledStepper("카운트인", value: $state.countInBars, range: 0...8, suffix: "마디")
            }

            Section("리듬") {
                polyrhythmRow
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.15), value: state.trainerEnabled)
    }

    /// 폴리리듬(마디당 보조 펄스) 컨트롤. 0/1이면 "끔", 그 외 "N : 주박수" 표기.
    private var polyrhythmRow: some View {
        Stepper(value: $state.polyPulses, in: 0...9) {
            LabeledContent("폴리리듬") {
                Text(state.polyPulses <= 1 ? "끔" : "\(state.polyPulses) : \(state.grid.count)")
                    .font(.monoTabular(size: 12))
                    .foregroundStyle(state.polyPulses <= 1 ? Theme.Colors.mut2 : Theme.Colors.ink)
            }
        }
        .accessibilityLabel("폴리리듬")
        .accessibilityValue(state.polyPulses <= 1 ? "끔" : "\(state.polyPulses) 대 \(state.grid.count)")
    }

    private func labeledStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        Stepper(value: value, in: range) {
            LabeledContent(title) {
                Text("\(value.wrappedValue) \(suffix)")
                    .font(.monoTabular(size: 12))
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(value.wrappedValue) \(suffix)")
    }
}
