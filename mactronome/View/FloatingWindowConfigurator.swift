// metronome/View/FloatingWindowConfigurator.swift
import SwiftUI
import AppKit

/// 호스팅된 창의 레벨을 조정해 "항상 위에(floating)" 동작을 토글하는 보조 뷰입니다.
/// 레이아웃에 영향을 주지 않는 0크기 NSView로 배경에 배치합니다.
struct FloatingWindowConfigurator: NSViewRepresentable {
    let floating: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 창은 뷰가 계층에 붙은 뒤에야 존재하므로 다음 런루프에 적용합니다.
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.level = floating ? .floating : .normal
        }
    }
}
