import SwiftUI

enum Palette {
    static let background = Color(red: 0.025, green: 0.025, blue: 0.030)
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let elevated = Color(red: 0.115, green: 0.115, blue: 0.128)
    static let line = Color.white.opacity(0.085)
    static let text = Color(red: 0.94, green: 0.93, blue: 0.90)
    static let muted = Color(red: 0.58, green: 0.58, blue: 0.60)
    static let accent = Color(red: 0.90, green: 0.82, blue: 0.67)
    static let onAccent = Color(red: 0.14, green: 0.11, blue: 0.085)
}

struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 62

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
struct RoundIcon: View {
    let name: String
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(Palette.text)
            .frame(width: 46, height: 46)
            .background(.black.opacity(0.65), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.08)))
    }
}
enum PageLayout {
    static let contentWidth: CGFloat = 640
    static let horizontalPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
}

struct PageHeading: View {
    let title: String
    var trailingText: String? = nil
    var trailingAccessibilityLabel: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if let trailingText {
                Text(trailingText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .monospacedDigit().foregroundStyle(Palette.muted)
                    .accessibilityLabel(trailingAccessibilityLabel ?? trailingText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
    }
}
struct SheetHeading: View {
    let title: String
    let close: () -> Void
    var body: some View {
        HStack {
            Text(title).font(.system(size: 21, weight: .medium)).foregroundStyle(Palette.text)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted).frame(width: 32, height: 32)
                    .background(Palette.elevated, in: Circle())
            }.accessibilityLabel("閉じる")
        }
    }
}
