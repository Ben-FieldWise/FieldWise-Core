import SwiftUI

// MARK: - GeoCard

struct GeoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5)
            )
    }
}

// MARK: - SectionHeader

struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconBg: Color
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - CheckRow

struct CheckRow: View {
    let text: String
    @Binding var isChecked: Bool
    var accentColor: Color = Color("GeoGreen")

    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isChecked ? accentColor : Color.gray.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isChecked ? accentColor : Color.white)
                        )
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(text)
                    .font(.system(size: 14))
                    // FIX: Changed to keep high text contrast (.primary) regardless of selected state, avoiding light-grey transparency decay
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isChecked ? accentColor.opacity(0.08) : Color("GeoSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isChecked)
    }
}

// MARK: - ChipToggle

struct ChipToggle: View {
    let label: String
    @Binding var isSelected: Bool
    var color: Color = Color("GeoGreen")

    var body: some View {
        Button(action: { isSelected.toggle() }) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color.white)
                .foregroundColor(isSelected ? .white : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? color : Color.gray.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - ProgressBar

struct GeoProgressBar: View {
    let value: Double
    var color: Color = Color("GeoGreen")

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * value))
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - BadgeView

struct BadgeView: View {
    let text: String
    let backgroundColor: Color
    let foregroundColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - RiskLevelPicker

struct RiskLevelPicker: View {
    let label: String
    @Binding var level: FieldworkPlan.RiskLevel

    var levelColor: Color {
        switch level {
        case .notSet: return .secondary
        case .low:    return Color("GeoGreen")
        case .medium: return Color("GeoAmber")
        case .high:   return Color("GeoCoral")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Menu {
                ForEach(FieldworkPlan.RiskLevel.allCases, id: \.self) { lvl in
                    Button(lvl.rawValue) { level = lvl }
                }
            } label: {
                HStack {
                    Text(level.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(level == .notSet ? .secondary : levelColor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color("GeoSurface"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// MARK: - StepDots

struct StepDotsView: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color("GeoGreen") : i < current ? Color("GeoGreen").opacity(0.4) : Color.black.opacity(0.1))
                    .frame(width: i == current ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - GeoTextField

struct GeoTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color("GeoSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            )
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    let iconName: String?
    let action: () -> Void
    var color: Color = Color("GeoGreen")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - FieldLabel

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
    }
}

// MARK: - Fixed Custom Back Navigation Elements

struct CustomBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .bold))
                // FIX: Swap faded gray with high contrast primary black tint for light mode visibility
                .foregroundColor(.primary) 
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}