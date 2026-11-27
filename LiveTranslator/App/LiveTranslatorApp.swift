import SwiftUI
import AppKit

@main
struct LiveTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { SettingsView(settings: delegate.settings) }
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button(delegate.settings.isNotes ? "切換至雙語字幕" : "切換至雙語筆記") {
                        delegate.settings.mode = delegate.settings.isNotes ? .subtitles : .notes
                    }.keyboardShortcut("n", modifiers: [.command, .shift])
                    Button("顯示字幕視窗") { delegate.showPanel() }
                        .keyboardShortcut("0", modifiers: .command)
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = CaptionViewModel()
    let settings = OverlaySettings()
    private var summaryWindow: SummaryWindowController?
    private var panel: FloatingPanel?
    private var terminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) { showPanel() }

    func showPanel() {
        if panel == nil {
            let panel = FloatingPanel()
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: CaptionOverlayView(model: model, settings: settings, showSummary: { [weak self] in
                self?.showSummary()
            }) { [weak self] in
                guard let self else { return }
                self.panel?.apply(self.settings)
            })
            panel.apply(settings)
            self.panel = panel
        }
        // Only an explicit show action orders the panel; caption updates never do so.
        panel?.orderFrontRegardless()
    }

    func showSummary() {
        if summaryWindow == nil { summaryWindow = SummaryWindowController(captionModel: model) }
        summaryWindow?.present(rows: model.captionRows)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    func windowWillClose(_ notification: Notification) { model.stop() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationPending || model.isExporting || model.isProtectingTranscript { return .terminateCancel }
        guard model.hasUnsavedChanges else { return .terminateNow }
        terminationPending = true
        // Start after returning terminateLater so save panels may finish asynchronously.
        DispatchQueue.main.async { [weak self] in
            guard let self else { sender.reply(toApplicationShouldTerminate: false); return }
            self.model.resolveUnsavedChanges(action: "結束") { [weak self] proceed in
                self?.terminationPending = false
                sender.reply(toApplicationShouldTerminate: proceed)
            }
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
