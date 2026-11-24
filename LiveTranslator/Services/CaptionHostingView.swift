import AppKit
import SwiftUI

/// Constrain SwiftUI's proposed width before asking for its full wrapped height.
final class CaptionHostingView: NSHostingView<AnyView> {
    required init(rootView: AnyView = AnyView(EmptyView())) {
        super.init(rootView: rootView)
        isFlipped = true
        sizingOptions = [.intrinsicContentSize]
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func fit(_ content: AnyView, width: CGFloat, minimumHeight: CGFloat) {
        let width = max(1, width)
        rootView = AnyView(content
            .frame(width: width, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true))
        frame.size.width = width
        layoutSubtreeIfNeeded()
        frame.size.height = max(minimumHeight, ceil(fittingSize.height))
    }
}
