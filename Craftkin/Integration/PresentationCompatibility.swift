import SwiftUI
import UIKit

enum CompatibleSheetSize: Hashable {
    case medium, large

    @available(iOS 16.0, *)
    var swiftUI: PresentationDetent { self == .medium ? .medium : .large }

    var uiKit: UISheetPresentationController.Detent { self == .medium ? .medium() : .large() }
}

extension View {
    @ViewBuilder func compatibleSheet(_ sizes: [CompatibleSheetSize], showsGrabber: Bool? = nil) -> some View {
        if #available(iOS 16.0, *) {
            if let showsGrabber {
                presentationDetents(Set(sizes.map(\.swiftUI)))
                    .presentationDragIndicator(showsGrabber ? .visible : .hidden)
            } else {
                presentationDetents(Set(sizes.map(\.swiftUI)))
            }
        } else {
            background(PresentationConfiguration(sizes: sizes, showsGrabber: showsGrabber)
                .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true))
        }
    }

    @ViewBuilder func compatibleNavigationBarBackground(_ color: Color) -> some View {
        if #available(iOS 16.0, *) {
            toolbarBackground(color, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        } else {
            background(PresentationConfiguration(navigationColor: UIColor(color))
                .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true))
        }
    }

}

struct CompatibleKeyboardScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            ScrollView { content }.scrollDismissesKeyboard(.interactively)
        } else {
            ScrollView {
                content.background(KeyboardDismissalConfiguration().frame(width: 0, height: 0)
                    .allowsHitTesting(false).accessibilityHidden(true))
            }
        }
    }
}

private struct PresentationConfiguration: UIViewControllerRepresentable {
    var sizes: [CompatibleSheetSize]? = nil
    var showsGrabber: Bool? = nil
    var navigationColor: UIColor? = nil

    func makeUIViewController(context: Context) -> Reader {
        let controller = Reader()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: Reader, context: Context) {
        controller.configuration = self
        controller.configure()
        DispatchQueue.main.async { [weak controller] in controller?.configure() }
    }

    final class Reader: UIViewController {
        var configuration = PresentationConfiguration()

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            configure()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            configure()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configure()
        }

        func configure() {
            var current: UIViewController? = self
            while let controller = current {
                if let sizes = configuration.sizes,
                   let sheet = controller.presentationController as? UISheetPresentationController {
                    sheet.detents = sizes.map(\.uiKit)
                    if let value = configuration.showsGrabber { sheet.prefersGrabberVisible = value }
                }
                if let color = configuration.navigationColor, let navigation = controller.navigationController {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = color
                    navigation.navigationBar.standardAppearance = appearance
                    navigation.navigationBar.scrollEdgeAppearance = appearance
                    navigation.navigationBar.compactAppearance = appearance
                }
                current = controller.parent
            }
        }
    }
}

private struct KeyboardDismissalConfiguration: UIViewRepresentable {
    func makeUIView(context: Context) -> Reader { Reader() }
    func updateUIView(_ view: Reader, context: Context) { view.configure() }

    final class Reader: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            configure()
        }

        func configure() {
            DispatchQueue.main.async { [weak self] in
                var current = self?.superview
                while let view = current {
                    if let scroll = view as? UIScrollView { scroll.keyboardDismissMode = .interactive; return }
                    current = view.superview
                }
            }
        }
    }
}

struct CompatibleShareButton: View {
    let title: String
    let url: URL
    @State private var isPresented = false

    var body: some View {
        Button(title) { isPresented = true }
            .sheet(isPresented: $isPresented) { ShareController(url: url) }
    }

    private struct ShareController: UIViewControllerRepresentable {
        let url: URL
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [url], applicationActivities: nil)
        }
        func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    }
}
