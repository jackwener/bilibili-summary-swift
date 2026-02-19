import SwiftUI

// MARK: - Toast View Modifier

struct ToastViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if isPresented {
                Text(message)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        self.modifier(ToastViewModifier(isPresented: isPresented, message: message))
    }
}

// MARK: - Toast State Helper

@MainActor
final class ToastViewModel: ObservableObject {
    @Published var isPresented = false
    @Published var message = ""

    func show(_ message: String, duration: TimeInterval = 2) {
        self.message = message
        withAnimation(.spring()) {
            isPresented = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeOut) {
                isPresented = false
            }
        }
    }
}
