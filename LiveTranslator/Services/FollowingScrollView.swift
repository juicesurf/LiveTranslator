import AppKit

/// Native scrolling distinguishes user movement from document layout changes.
final class FollowingScrollView: NSScrollView {
    private(set) var followsLatest = true
    private var changingContent = false
    var layoutDocument: (() -> Void)?
    private var previousSize = NSSize.zero
    private var boundsObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hasVerticalScroller = true
        drawsBackground = false
        contentView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: contentView, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.changingContent else { return }
                self.followsLatest = self.isAtBottom
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        guard contentSize != previousSize else { return }
        previousSize = contentSize
        updateDocument { layoutDocument?() }
    }

    private var isAtBottom: Bool {
        guard let documentView else { return true }
        return documentView.frame.height - contentView.bounds.maxY <= 4
    }

    override func scrollWheel(with event: NSEvent) {
        // Stop following before AppKit processes a wheel/trackpad event.
        followsLatest = false
        super.scrollWheel(with: event)
        followsLatest = isAtBottom
    }

    func updateDocument(_ update: () -> Void) {
        let follow = followsLatest
        let origin = contentView.bounds.origin
        changingContent = true
        update()
        if let documentView {
            let maximum = max(0, documentView.frame.height - contentView.bounds.height)
            contentView.scroll(to: NSPoint(x: origin.x, y: follow ? maximum : min(origin.y, maximum)))
            reflectScrolledClipView(contentView)
        }
        followsLatest = follow
        changingContent = false
    }
}

