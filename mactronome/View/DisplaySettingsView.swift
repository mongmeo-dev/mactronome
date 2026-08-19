// metronome/View/DisplaySettingsView.swift
import SwiftUI

/// 표시/창 설정: 비주얼 플래시, 화면 모드, 항상 위에.
struct DisplaySettingsView: View {
    @ObservedObject var state: MetronomeState

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("비주얼 플래시")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut)
                Spacer()
                Toggle("", isOn: $state.visualFlash)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Theme.Colors.acc)
                    .accessibilityLabel("비주얼 플래시")
            }

            HStack {
                Text("화면 모드")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut)
                Spacer()
                Picker("", selection: $state.appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel("화면 모드")
            }

            HStack {
                Text("항상 위에")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut)
                Spacer()
                Toggle("", isOn: $state.floating)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Theme.Colors.acc)
                    .accessibilityLabel("항상 위에")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
    }
}
