import SwiftUI

/// 2-letter initials avatar. Gray asleep, orange ring snoozed, green up.
/// First up gets a green ring, last up a red ring.
struct AvatarView: View {
    enum State { case asleep, snoozed, up }
    let initials: String
    var state: State = .up
    var tag: String? = nil
    var isYou = false
    var size: CGFloat = 30
    var photo: UIImage? = nil

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Circle().fill(fill)
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(state == .up ? Color.green : .secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(ring, lineWidth: ringWidth) }
        .overlay(alignment: .bottomTrailing) {
            if isYou && size < 60 {
                Circle().fill(.blue).frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(.black, lineWidth: 1.5))
            }
        }
    }

    private var fill: Color {
        switch state {
        case .up: Color.green.opacity(0.2)
        case .snoozed, .asleep: Color(white: 0.2)
        }
    }
    private var ring: Color {
        if tag == "first" { return .green }
        if tag == "last" { return .red }
        return state == .snoozed ? .orange : .clear
    }
    private var ringWidth: CGFloat { tag != nil || state == .snoozed ? 2 : 0 }
}
