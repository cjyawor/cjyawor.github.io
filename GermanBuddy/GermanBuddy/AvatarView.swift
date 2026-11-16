import SwiftUI

/// Cartoon avatar drawn in SwiftUI. Blinks, bobs while thinking, and opens its mouth on each spoken word.
struct AvatarView: View {
    let phase: Phase
    let wordTick: Int

    @State private var blink = false
    @State private var mouth: CGFloat = 0.1
    @State private var bob = false

    var body: some View {
        ZStack {
            // hair back
            RoundedRectangle(cornerRadius: 90).fill(Color(red: 0.93, green: 0.72, blue: 0.25))
                .frame(width: 210, height: 230).offset(y: 10)
            // face
            Circle().fill(Color(red: 0.99, green: 0.84, blue: 0.72))
                .frame(width: 180, height: 180)
            // fringe
            Capsule().fill(Color(red: 0.93, green: 0.72, blue: 0.25))
                .frame(width: 170, height: 50).offset(y: -78)
            // cheeks
            HStack(spacing: 80) {
                Circle().fill(.pink.opacity(0.25)).frame(width: 28)
                Circle().fill(.pink.opacity(0.25)).frame(width: 28)
            }.offset(y: 22)
            // eyes
            HStack(spacing: 56) {
                Eye(closed: blink); Eye(closed: blink)
            }.offset(y: -10)
            // brows
            HStack(spacing: 50) {
                Capsule().fill(.brown).frame(width: 30, height: 5).rotationEffect(.degrees(phase == .thinking ? -12 : 0))
                Capsule().fill(.brown).frame(width: 30, height: 5).rotationEffect(.degrees(phase == .thinking ? 12 : 0))
            }.offset(y: -42)
            // mouth
            Ellipse().fill(Color(red: 0.62, green: 0.15, blue: 0.2))
                .frame(width: 44 - mouth * 12, height: 6 + mouth * 34)
                .offset(y: 52)
        }
        .frame(width: 240, height: 260)
        .offset(y: bob ? -6 : 0)
        .rotationEffect(.degrees(phase == .thinking ? 4 : 0))
        .animation(.easeInOut(duration: 0.4), value: phase)
        .onChange(of: wordTick) { _ in
            withAnimation(.easeOut(duration: 0.07)) { mouth = CGFloat.random(in: 0.5...1.0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeIn(duration: 0.1)) { mouth = 0.1 }
            }
        }
        .onChange(of: phase) { p in
            if p != .speaking { withAnimation { mouth = 0.1 } }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
                blink = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { blink = false }
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bob = true }
        }
    }
}

private struct Eye: View {
    let closed: Bool
    var body: some View {
        ZStack {
            Ellipse().fill(.white).frame(width: 30, height: closed ? 3 : 30)
            Circle().fill(Color(red: 0.2, green: 0.4, blue: 0.7)).frame(width: 15).opacity(closed ? 0 : 1)
            Circle().fill(.black).frame(width: 7).opacity(closed ? 0 : 1)
        }
    }
}
