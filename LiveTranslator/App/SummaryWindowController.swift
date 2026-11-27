import AppKit
import SwiftUI

@MainActor
final class SummaryWindowController: NSWindowController, NSWindowDelegate {
    let model = SummaryViewModel()

    init(captionModel: CaptionViewModel) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "本次重點"
        window.minSize = NSSize(width: 620, height: 480)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = true
        window.center()
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: SummaryView(model: model) { [weak self, weak captionModel] in
            guard let self, let captionModel else { return }
            self.model.start(rows: captionModel.captionRows)
        })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(rows: [CaptionDisplayRow]) {
        if model.result == nil && !model.isRunning { model.start(rows: rows) }
        // This is an explicit user request; background summary updates never activate windows.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { model.cancel() }
}
