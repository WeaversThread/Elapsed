import SwiftUI

// MARK: - Layout

/// A titled group of rows on a faint surface.
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if let footer {
                Text(footer)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 2)
            }
        }
    }
}

struct SettingsRow<Control: View>: View {
    let label: String
    var detail: String? = nil
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.75))
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 34)
    }
}

/// Hairline between rows inside a section.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 10)
    }
}

// MARK: - Controls

struct GlassSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        HoverButton {
            withAnimation(.spring(duration: 0.2)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(Color.white.opacity(isOn ? 0.7 : 0.12))
                Circle()
                    .fill(isOn ? Color(white: 0.12) : Color.white.opacity(0.55))
                    .padding(2)
            }
            .frame(width: 28, height: 16)
        }
        .accessibilityValue(isOn ? "on" : "off")
    }
}

/// Text options in a capsule, one selected.
struct GlassChoice<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                HoverButton {
                    withAnimation(.spring(duration: 0.2)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(Color.white.opacity(isSelected ? 0.9 : 0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(isSelected ? 0.14 : 0)))
                }
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

struct GlassStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String = ""

    var body: some View {
        HStack(spacing: 6) {
            step("minus", by: -1)
            Text("\(value)\(suffix)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(minWidth: 48)
                .contentTransition(.numericText())
            step("plus", by: 1)
        }
    }

    private func step(_ symbol: String, by delta: Int) -> some View {
        HoverButton {
            withAnimation(.spring(duration: 0.2)) {
                value = min(max(value + delta, range.lowerBound), range.upperBound)
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .accessibilityLabel(delta < 0 ? "Less" : "More")
    }
}

struct SwatchPicker: View {
    @Binding var selection: Accent

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Accent.allCases) { accent in
                HoverButton {
                    withAnimation(.spring(duration: 0.2)) { selection = accent }
                } label: {
                    Circle()
                        .fill(accent.color.opacity(0.85))
                        .frame(width: 14, height: 14)
                        .padding(2.5)
                        .overlay(
                            Circle().strokeBorder(
                                Color.white.opacity(selection == accent ? 0.85 : 0),
                                lineWidth: 1.5
                            )
                        )
                }
                .accessibilityLabel(accent.rawValue)
            }
        }
    }
}

/// Volume as a wedge of bars, in the slider's visual language.
struct VolumeBars: View {
    @Binding var value: Double
    var onCommit: () -> Void = {}

    private let count = 24

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    let fraction = Double(i + 1) / Double(count)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(fraction <= value + 0.001 ? 0.75 : 0.12))
                        .frame(width: 2, height: 5 + 11 * fraction)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 16, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = drag.location.x / max(geo.size.width, 1)
                        value = (min(max(fraction, 1.0 / Double(count)), 1) * Double(count)).rounded() / Double(count)
                    }
                    .onEnded { _ in onCommit() }
            )
        }
        .frame(width: 140, height: 16)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// MARK: - Presets

/// The preset chips: click one to type a new value, hover for ×, + to add one.
struct PresetEditor: View {
    @Binding var presets: [Int]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(presets.enumerated()), id: \.element) { index, minutes in
                PresetChip(
                    minutes: minutes,
                    canDelete: presets.count > Preferences.presetCountRange.lowerBound,
                    onChange: { replace(at: index, with: $0) },
                    onDelete: { remove(at: index) }
                )
            }

            if presets.count < Preferences.presetCountRange.upperBound {
                HoverButton(action: add) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .accessibilityLabel("Add preset")
            }

            Spacer(minLength: 0)
        }
    }

    private func replace(at index: Int, with value: Int) {
        let value = PomodoroSegment.clampMinutes(value)
        guard presets.indices.contains(index), !presets.contains(value) else { return }
        var updated = presets
        updated[index] = value
        withAnimation(.spring(duration: 0.2)) { presets = updated.sorted() }
    }

    private func remove(at index: Int) {
        guard presets.indices.contains(index),
              presets.count > Preferences.presetCountRange.lowerBound else { return }
        var updated = presets
        updated.remove(at: index)
        withAnimation(.spring(duration: 0.2)) { presets = updated }
    }

    private func add() {
        var candidate = PomodoroSegment.clampMinutes((presets.max() ?? 0) + 15)
        while presets.contains(candidate) && candidate > 1 { candidate -= 1 }
        guard !presets.contains(candidate) else { return }
        withAnimation(.spring(duration: 0.2)) { presets = (presets + [candidate]).sorted() }
    }
}

private struct PresetChip: View {
    let minutes: Int
    let canDelete: Bool
    let onChange: (Int) -> Void
    let onDelete: () -> Void

    @State private var text: String
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    init(minutes: Int, canDelete: Bool, onChange: @escaping (Int) -> Void, onDelete: @escaping () -> Void) {
        self.minutes = minutes
        self.canDelete = canDelete
        self.onChange = onChange
        self.onDelete = onDelete
        _text = State(initialValue: "\(minutes)")
    }

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(width: 30, height: 22)
            .background(Capsule().fill(Color.white.opacity(isFocused ? 0.16 : 0.08)))
            .focused($isFocused)
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .overlay(alignment: .topTrailing) {
                if isHovered && canDelete && !isFocused {
                    HoverButton(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .frame(width: 12, height: 12)
                            .background(Circle().fill(Color(white: 0.32)))
                    }
                    .offset(x: 4, y: -4)
                    .accessibilityLabel("Remove \(minutes)")
                    .transition(.opacity)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
    }

    private func commit() {
        let value = Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
        if value > 0 && value != minutes {
            onChange(value)
        }
        // Rejected or unchanged: show the real value again.
        text = "\(minutes)"
    }
}
