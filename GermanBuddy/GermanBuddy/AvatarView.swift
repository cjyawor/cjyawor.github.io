import SwiftUI

/// On-device avatar. Costs nothing per use. Blinks, glances around, bobs while thinking,
/// and moves lips on every spoken word.
struct AvatarView: View {
    let phase: Phase
    let wordTick: Int

    @State private var blink = false
    @State private var mouth: CGFloat = 0
    @State private var bob = false
    @State private var gaze: CGSize = .zero

    private let skin = LinearGradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.78),
                                               Color(red: 0.96, green: 0.77, blue: 0.64)],
                                      startPoint: .top, endPoint: .bottom)
    private let hair = LinearGradient(colors: [Color(red: 0.56, green: 0.36, blue: 0.2),
                                               Color(red: 0.38, green: 0.22, blue: 0.12)],
                                      startPoint: .top, endPoint: .bottom)

    var body: some View {
        ZStack {
            // hair behind the head, falls past the shoulders
            RoundedRectangle(cornerRadius: 100).fill(hair)
                .frame(width: 220, height: 270).offset(y: 30)
            // shoulders and top
            RoundedRectangle(cornerRadius: 40).fill(Color(red: 0.2, green: 0.45, blue: 0.55))
                .frame(width: 210, height: 80).offset(y: 130)
            // neck
            Rectangle().fill(skin).frame(width: 52, height: 50).offset(y: 100)
            // face
            Ellipse().fill(skin).frame(width: 168, height: 190)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
            // side locks
            HStack(spacing: 150) {
                Capsule().fill(hair).frame(width: 22, height: 120)
                Capsule().fill(hair).frame(width: 22, height: 120)
            }.offset(y: -4)
            // fringe, swept to one side
            Ellipse().fill(hair).frame(width: 190, height: 80).offset(x: -6, y: -82)
            Ellipse().fill(skin).frame(width: 90, height: 40).offset(x: 34, y: -62)
            // cheeks
            HStack(spacing: 84) {
                Circle().fill(.pink.opacity(0.22)).frame(width: 30)
                Circle().fill(.pink.opacity(0.22)).frame(width: 30)
            }.offset(y: 24)
            // eyes
            HStack(spacing: 50) {
                Eye(closed: blink, gaze: gaze)
                Eye(closed: blink, gaze: gaze)
            }.offset(y: -14)
            // brows
            HStack(spacing: 44) {
                Capsule().fill(Color(red: 0.35, green: 0.2, blue: 0.1)).frame(width: 32, height: 5)
                    .rotationEffect(.degrees(phase == .thinking ? -10 : 4))
                Capsule().fill(Color(red: 0.35, green: 0.2, blue: 0.1)).frame(width: 32, height: 5)
                    .rotationEffect(.degrees(phase == .thinking ? 14 : -4))
            }.offset(y: -46).offset(y: phase == .thinking ? -3 : 0)
            // nose
            Capsule().fill(Color(red: 0.88, green: 0.62, blue: 0.5).opacity(0.55))
                .frame(width: 8, height: 18).offset(y: 14)
            // mouth
            MouthView(open: mouth, smile: phase == .listening ? 0.7 : 0.4)
                .frame(width: 56, height: 40).offset(y: 52)
        }
        .frame(width: 260, height: 300)
        .offset(y: bob ? -5 : 0)
        .rotationEffect(.degrees(phase == .thinking ? 4 : 0), anchor: .bottom)
        .animation(.easeInOut(duration: 0.4), value: phase)
        .onChange(of: wordTick) { _ in
            withAnimation(.easeOut(duration: 0.07)) { mouth = CGFloat.random(in: 0.45...1.0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeIn(duration: 0.1)) { mouth = 0.08 }
            }
        }
        .onChange(of: phase) { p in
            if p != .speaking { withAnimation { mouth = 0 } }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.4, repeats: true) { _ in
                blink = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { blink = false }
            }
            Timer.scheduledTimer(withTimeInterval: 2.6, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    gaze = CGSize(width: CGFloat.random(in: -3...3), height: CGFloat.random(in: -2...2))
                }
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { bob = true }
        }
    }
}

private struct Eye: View {
    let closed: Bool
    let gaze: CGSize
    var body: some View {
        ZStack {
            Ellipse().fill(.white).frame(width: 30, height: closed ? 3 : 26)
            Circle().fill(Color(red: 0.25, green: 0.5, blue: 0.4)).frame(width: 16)
                .offset(gaze).opacity(closed ? 0 : 1)
            Circle().fill(.black).frame(width: 7).offset(gaze).opacity(closed ? 0 : 1)
            Circle().fill(.white).frame(width: 4).offset(x: gaze.width + 2, y: gaze.height - 2)
                .opacity(closed ? 0 : 1)
            // upper lash line
            Capsule().fill(Color(red: 0.2, green: 0.12, blue: 0.08)).frame(width: 32, height: 3)
                .offset(y: closed ? 0 : -12)
        }
    }
}

/// Lips with teeth and tongue. `open` runs 0 (closed) to 1 (wide).
private struct MouthView: View {
    var open: CGFloat
    var smile: CGFloat

    var body: some View {
        ZStack {
            MouthShape(open: open, smile: smile).fill(Color(red: 0.45, green: 0.1, blue: 0.14))
            // teeth
            MouthShape(open: open, smile: smile)
                .fill(.white)
                .mask(Rectangle().frame(height: 10 * open + 0.1).offset(y: -4 - 4 * open))
                .opacity(open > 0.15 ? 1 : 0)
            // tongue
            Ellipse().fill(Color(red: 0.85, green: 0.35, blue: 0.4))
                .frame(width: 26, height: 10 * open).offset(y: 8 * open)
                .mask(MouthShape(open: open, smile: smile))
            // lip outline
            MouthShape(open: open, smile: smile)
                .stroke(Color(red: 0.75, green: 0.3, blue: 0.35), lineWidth: 3)
        }
    }
}

private struct MouthShape: Shape {
    var open: CGFloat
    var smile: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(open, smile) }
        set { open = newValue.first; smile = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let midY = r.midY
        let corner = 6 * smile
        let left = CGPoint(x: r.minX + 4, y: midY - corner)
        let right = CGPoint(x: r.maxX - 4, y: midY - corner)
        let drop = 4 + 30 * open
        p.move(to: left)
        // upper lip
        p.addQuadCurve(to: right, control: CGPoint(x: r.midX, y: midY - 6 - 2 * open))
        // lower lip
        p.addQuadCurve(to: left, control: CGPoint(x: r.midX, y: midY + drop + 6 * smile))
        p.closeSubpath()
        return p
    }
}
