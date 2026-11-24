import AppKit
import Testing
@testable import LiveTranslatorCore

@MainActor
struct FollowingScrollViewTests {
    private final class Document: NSView {
        override var isFlipped: Bool { true }
    }

    @Test func scrollingUpPreservesPositionAcrossNewCaptionsAndTranslations() {
        let scroll = FollowingScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        let document = Document(frame: NSRect(x: 0, y: 0, width: 480, height: 1500))
        scroll.documentView = document
        scroll.layoutSubtreeIfNeeded()
        scroll.updateDocument {}
        #expect(scroll.followsLatest)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 250))
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        #expect(!scroll.followsLatest)
        for height in [1600.0, 1700.0, 2000.0] {
            scroll.updateDocument { document.frame.size.height = height }
            #expect(scroll.contentView.bounds.origin.y == 250)
            #expect(!scroll.followsLatest)
        }
    }

    @Test func returningToBottomRestoresFollowing() {
        let scroll = FollowingScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        let document = Document(frame: NSRect(x: 0, y: 0, width: 480, height: 1500))
        scroll.documentView = document
        scroll.layoutSubtreeIfNeeded()
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        #expect(!scroll.followsLatest)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: document.frame.height - scroll.contentView.bounds.height))
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        #expect(scroll.followsLatest)
        scroll.updateDocument { document.frame.size.height = 1800 }
        #expect(abs(scroll.contentView.bounds.maxY - document.frame.height) < 1)
        #expect(scroll.followsLatest)
    }
}
