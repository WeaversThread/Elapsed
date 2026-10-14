import SwiftUI

struct TimerSliderView: View {
    @Binding var minutes: Int
    let isRunning: Bool
    let progress: Double
    @Binding var showCustomInput: Bool
    var isBreak: Bool = false
    /// Called when the custom field gets a clock time like "@14:30".
    var onStartUntil: ((Date) -> Void)? = nil

    @EnvironmentObject private var store: UserDefaultsStore
    @State private var dragFraction: Double? = nil
    @State private var isDragging = false
    @State private var customTimeText = ""
    @FocusState private var isCustomInputFocused: Bool

    private let maxSliderMinutes = 120
    private let barCount = 60
    private let barWidth: CGFloat = 2
    private let barHeightMin: CGFloat = 8
    private let barHeightMax: CGFloat = 24
    private let growRadius: Double = 5

    private var visualFraction: Double {
        if isRunning { return 1.0 - progress }
        return dragFraction ?? normalizedValue
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let totalWidth = geo.size.width

                HStack(spacing: 0) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let barFraction = Double(i) / Double(barCount - 1)
                        let distance = abs(barFraction - visualFraction) * Double(barCount)
                        let growFactor = max(0, 1.0 - distance / growRadius)
                        let height = barHeightMin + (barHeightMax - barHeightMin) * growFactor

                        let isFilled = barFraction <= visualFraction
                        let filledColor: Color = store.prefs.accent(for: isBreak ? .rest : .focus)
                            .opacity(isBreak ? 0.6 : 0.7)
                        let barColor: Color = isRunning
                            ? (isFilled ? filledColor : Color.white.opacity(0.12))
                            : (isFilled ? Color.white.opacity(0.75) : Color.white.opacity(0.12))

                        RoundedRectangle(cornerRadius: 1)
                            .fill(barColor)
                            .frame(width: barWidth, height: height)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: barHeightMax)
                .contentShape(Rectangle().inset(by: -20))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !isRunning else { return }
                            isDragging = true
                            let fraction = value.location.x / totalWidth
                            let clamped = min(max(fraction, 0), 1.05)

                            dragFraction = min(clamped, 1.0)

                            if clamped > 1.0 {
                                withAnimation(.spring(duration: 0.25)) {
                                    showCustomInput = true
                                }
                                minutes = maxSliderMinutes
                            } else {
                                showCustomInput = false
                                minutes = max(1, Int(round(clamped * Double(maxSliderMinutes))))
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            withAnimation(.spring(duration: 0.2)) {
                                dragFraction = nil
                            }
                        }
                )
                .animation(isDragging ? nil : .spring(duration: 0.3, bounce: 0.15), value: visualFraction)
            }
            .frame(height: barHeightMax)

            if showCustomInput {
                HStack(spacing: 8) {
                    Text("Custom")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.4))

                    TextField("90, 1:30 or @14:30", text: $customTimeText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .frame(width: 130)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .focused($isCustomInputFocused)
                        .onSubmit { applyCustomTime() }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear { isCustomInputFocused = true }
            }
        }
    }

    private var normalizedValue: Double {
        Double(min(minutes, maxSliderMinutes)) / Double(maxSliderMinutes)
    }

    private func applyCustomTime() {
        switch TimeInputParser.parse(customTimeText) {
        case .minutes(let m):
            minutes = m
        case .until(let date):
            customTimeText = ""
            withAnimation(.spring(duration: 0.25)) {
                showCustomInput = false
            }
            onStartUntil?(date)
        case nil:
            NSSound.beep()
        }
    }
}
