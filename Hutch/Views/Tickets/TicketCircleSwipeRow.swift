import SwiftUI

struct SwipeCircleAction {
    let label: String
    let systemImage: String
    let color: Color
    let handler: () -> Void
}

struct TicketCircleSwipeRow<Content: View>: View {
    let content: Content
    let leadingAction: SwipeCircleAction?
    let trailingAction: SwipeCircleAction?

    @State private var offset: CGFloat = 0

    private let circleSize: CGFloat = 60
    private let revealDistance: CGFloat = 88
    private let triggerDistance: CGFloat = 140

    init(
        leadingAction: SwipeCircleAction? = nil,
        trailingAction: SwipeCircleAction? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .center) {
            if leadingAction != nil {
                HStack {
                    leadingCircle
                        .padding(.leading, 16)
                    Spacer()
                }
            }

            if trailingAction != nil {
                HStack {
                    Spacer()
                    trailingCircle
                        .padding(.trailing, 16)
                }
            }

            content
                .offset(x: clampedOffset)
                .gesture(dragGesture)
        }
        .clipped()
    }

    @ViewBuilder
    private var leadingCircle: some View {
        if let action = leadingAction {
            let progress = min(max(offset / revealDistance, 0), 1)
            circleButton(action: action, progress: progress)
        }
    }

    @ViewBuilder
    private var trailingCircle: some View {
        if let action = trailingAction {
            let progress = min(max(-offset / revealDistance, 0), 1)
            circleButton(action: action, progress: progress)
        }
    }

    @ViewBuilder
    private func circleButton(action: SwipeCircleAction, progress: CGFloat) -> some View {
        Button {
            fire(action)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(action.color)
                        .frame(width: circleSize, height: circleSize)

                    Image(systemName: action.systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }

                Text(action.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .opacity(progress)
        .scaleEffect(0.7 + 0.3 * progress, anchor: .center)
        .animation(.spring(duration: 0.2), value: progress)
    }

    private var clampedOffset: CGFloat {
        if offset > 0 {
            return leadingAction != nil ? min(offset, revealDistance + 16) : 0
        } else {
            return trailingAction != nil ? max(offset, -(revealDistance + 16)) : 0
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                if dx > 0, leadingAction != nil {
                    offset = dx
                } else if dx < 0, trailingAction != nil {
                    offset = dx
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                if dx > triggerDistance, let action = leadingAction {
                    fire(action)
                } else if dx < -triggerDistance, let action = trailingAction {
                    fire(action)
                } else {
                    snapBack()
                }
            }
    }

    private func fire(_ action: SwipeCircleAction) {
        snapBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            action.handler()
        }
    }

    private func snapBack() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            offset = 0
        }
    }
}
