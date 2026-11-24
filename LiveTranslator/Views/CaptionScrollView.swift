import AppKit
import SwiftUI

struct CaptionScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeNSView(context: Context) -> FollowingScrollView {
        let scroll = FollowingScrollView(frame: .zero)
        let host = CaptionHostingView()
        scroll.documentView = host
        return scroll
    }

    func updateNSView(_ scroll: FollowingScrollView, context: Context) {
        guard let host = scroll.documentView as? CaptionHostingView else { return }
        scroll.layoutDocument = { [weak scroll, weak host] in
            guard let scroll, let host else { return }
            host.fit(AnyView(content), width: scroll.contentSize.width, minimumHeight: scroll.contentSize.height)
        }
        scroll.updateDocument {
            scroll.layoutDocument?()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FollowingScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 640, height: proposal.height ?? 300)
    }
}
