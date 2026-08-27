import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ToastType: Equatable {
    case success
    case error
    case info
    case warning

    var color: Color {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .success:
                DesignTokens.success
            case .error:
                DesignTokens.error
            case .info:
                DesignTokens.accent
            case .warning:
                DesignTokens.warning
        }
        // swiftlint:enable switch_case_alignment
    }
}

struct ToastData: Equatable {
    let id: UUID
    let message: String
    let type: ToastType

    init(message: String, type: ToastType) {
        id = UUID()
        self.message = message
        self.type = type
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
final class ToastCenter {
    var current: ToastData?
    private var task: Task<Void, Never>?

    func show(_ message: String, type: ToastType) {
        let duration: Double
        if message.count < 60 {
            duration = 3
        } else if message.count < 150 {
            duration = 4
        } else {
            duration = 5
        }
        task?.cancel()
        current = ToastData(message: message, type: type)
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.current = nil
            }
        }
    }

    func dismiss() {
        task?.cancel()
        current = nil
    }
}

struct ToastView: View {
    let data: ToastData

    var body: some View {
        Text(data.message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.spacing16)
            .padding(.vertical, DesignTokens.spacing12)
            .background(data.type.color)
            .clipShape(Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(data.message)
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                #if canImport(UIKit)
                UIAccessibility.post(notification: .announcement, argument: data.message)
                #endif
            }
    }
}

extension View {
    func toast(center: ToastCenter) -> some View {
        overlay(alignment: .top) {
            if let data = center.current {
                ToastView(data: data)
                    .padding(.top, DesignTokens.spacing16)
                    .onTapGesture {
                        center.dismiss()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: center.current)
    }
}
