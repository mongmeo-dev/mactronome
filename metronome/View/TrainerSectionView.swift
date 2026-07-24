// metronome/View/TrainerSectionView.swift
import SwiftUI

/// 연습 도구 패널: 템포 트레이너(자동 가속)와 카운트인 설정.
struct TrainerSectionView: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        VStack(spacing: 12) {
            // 자동 가속 토글
            HStack {
                Text("자동 가속")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut)
                Spacer()
                Toggle("", isOn: $state.trainerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Theme.Colors.acc)
                    .accessibilityLabel("자동 가속")
            }

            if state.trainerEnabled {
                labeledStepper("마디마다", value: $state.trainerEveryBars, range: 1...32, suffix: "마디")
                labeledStepper("올릴 BPM", value: $state.trainerBPMStep, range: 1...30, suffix: "BPM")
                labeledStepper("목표 BPM", value: $state.trainerTargetBPM,
                               range: Int(MetronomeState.bpmRange.lowerBound)...Int(MetronomeState.bpmRange.upperBound),
                               suffix: "BPM")
            }

            Divider().overlay(Theme.Colors.bd)

            labeledStepper("카운트인", value: $state.countInBars, range: 0...8, suffix: "마디")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
    }

    private func labeledStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.Colors.mut)
            Spacer()
            Text("\(value.wrappedValue) \(suffix)")
                .font(.monoTabular(size: 12))
                .foregroundStyle(Theme.Colors.ink)
            Stepper("", value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }
}
