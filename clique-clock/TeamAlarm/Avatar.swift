import SwiftUI

/// 2-letter initials avatar. Grey asleep, dark green ring snoozed, green up.
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
                    .font(.gothamBold(size * 0.36))
                    .foregroundStyle(state == .up ? Clique.ink : .white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(ring, lineWidth: ringWidth) }
        .overlay(alignment: .bottomTrailing) {
            if isYou && size < 60 {
                Circle().fill(.white).frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(Clique.ink, lineWidth: 1.5))
            }
        }
    }

    private var fill: Color {
        switch state {
        case .up: Clique.green
        case .snoozed, .asleep: Clique.panel
        }
    }
    private var ring: Color {
        if tag == "first" { return Clique.green }
        if tag == "last" { return Clique.blood }
        return state == .snoozed ? Clique.moss : .clear
    }
    private var ringWidth: CGFloat { tag != nil || state == .snoozed ? 2 : 0 }
}
