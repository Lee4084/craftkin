import SwiftUI
import UIKit

enum CompatibleSymbol {
    static func name(_ preferred: String, fallback: String) -> String {
        UIImage(systemName: preferred) == nil ? fallback : preferred
    }
}

struct CompatibleNavigation<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }.navigationViewStyle(.stack)
        }
    }
}

struct CompatibleEmptyState: View {
    let title: String
    let systemImage: String
    let description: Text

    init(_ title: String, systemImage: String, description: Text) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack(spacing: 12) {
                Image(systemName: systemImage).font(.largeTitle).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                description.font(.subheadline).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}

struct CompatibleAdaptiveLayout<Horizontal: View, Vertical: View>: View {
    @ViewBuilder let horizontal: Horizontal
    @ViewBuilder let vertical: Vertical

    var body: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) { horizontal; vertical }
        } else {
            vertical
        }
    }
}

private struct CompatibleLineLimit: ViewModifier {
    let minimum: Int
    let maximum: Int
    let reservesSpace: Bool
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 21

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            if reservesSpace { content.lineLimit(maximum, reservesSpace: true) }
            else { content.lineLimit(minimum...maximum) }
        } else {
            content.lineLimit(maximum)
                .frame(minHeight: lineHeight * CGFloat(minimum), alignment: .topLeading)
        }
    }
}

extension View {
    func compatibleLineLimit(_ range: ClosedRange<Int>) -> some View {
        modifier(CompatibleLineLimit(minimum: range.lowerBound, maximum: range.upperBound, reservesSpace: false))
    }

    func compatibleLineLimit(_ limit: Int, reservesSpace: Bool) -> some View {
        modifier(CompatibleLineLimit(minimum: reservesSpace ? limit : 0, maximum: limit, reservesSpace: reservesSpace))
    }
}

struct CompatibleMultilineField: View {
    let title: String
    @Binding var text: String
    var lines: ClosedRange<Int>? = nil
    var textStyle: UIFont.TextStyle = .body
    var color: UIColor = .label
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 21

    init(_ title: String, text: Binding<String>, lines: ClosedRange<Int>? = nil,
         textStyle: UIFont.TextStyle = .body, color: UIColor = .label) {
        self.title = title
        _text = text
        self.lines = lines
        self.textStyle = textStyle
        self.color = color
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            if let lines { TextField(title, text: $text, axis: .vertical).lineLimit(lines) }
            else { TextField(title, text: $text, axis: .vertical) }
        } else {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(title).foregroundStyle(.secondary).padding(.top, 6)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                MultilineInput(text: $text, title: title, textStyle: textStyle, color: color)
            }
            .frame(height: lineHeight * CGFloat(lines?.upperBound ?? 4) + 12)
        }
    }

    private struct MultilineInput: UIViewRepresentable {
        @Binding var text: String
        let title: String
        let textStyle: UIFont.TextStyle
        let color: UIColor

        func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
        func makeUIView(context: Context) -> UITextView {
            let view = UITextView()
            view.backgroundColor = .clear
            view.textContainer.lineFragmentPadding = 0
            view.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
            view.adjustsFontForContentSizeCategory = true
            view.delegate = context.coordinator
            return view
        }
        func updateUIView(_ view: UITextView, context: Context) {
            context.coordinator.parent = self
            if view.text != text { view.text = text }
            view.accessibilityLabel = title
            view.font = .preferredFont(forTextStyle: textStyle)
            view.textColor = color
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            var parent: MultilineInput
            init(parent: MultilineInput) { self.parent = parent }
            func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        }
    }
}
