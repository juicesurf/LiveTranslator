import SwiftUI
@preconcurrency import Translation

struct CaptionOverlayView: View {
    @Bindable var model: CaptionViewModel
    @Bindable var settings: OverlaySettings
    var applyWindowSettings: () -> Void
    @State private var showsSettings = false
    @State private var showsDiagnostics = false

    private var colorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(model.running ? "停止" : "開始擷取", systemImage: model.running ? "pause.fill" : "play.fill") {
                    if model.running { model.stop() } else { model.start() }
                }
                Menu {
                    Button("儲存 TXT") { model.saveTranscript(format: .txt) }
                    Button("儲存 Markdown") { model.saveTranscript(format: .markdown) }
                } label: { Label("儲存", systemImage: "square.and.arrow.down") }
                    .fixedSize()
                    .disabled(model.captionRows.isEmpty || model.isExporting || model.isProtectingTranscript)
                Button("清除", systemImage: "trash") { model.requestClearCaptions() }
                    .disabled(model.captionRows.isEmpty || model.isExporting || model.isProtectingTranscript)
                Spacer(minLength: 0)
                Button(settings.alwaysOnTop ? "取消置頂" : "保持置頂", systemImage: settings.alwaysOnTop ? "pin.fill" : "pin") {
                    settings.alwaysOnTop.toggle()
                }.labelStyle(.iconOnly).help(settings.alwaysOnTop ? "取消置頂" : "保持置頂")
                Button("顯示設定", systemImage: "textformat.size") { showsSettings.toggle() }
                    .labelStyle(.iconOnly)
                    .popover(isPresented: $showsSettings) { SettingsView(settings: settings) }
                Menu {
                    Button("授予輔助使用權限") { model.requestPermission() }
                    Button("開啟權限設定") { model.openAccessibilitySettings() }
                    Divider()
                    Button("準備模型／重試翻譯") { model.prepareTranslation() }
                    Button("測試英翻繁中") { model.setEnglish("Welcome to this lecture. Today we will learn something new.") }
                    Toggle("顯示診斷", isOn: $showsDiagnostics)
                } label: { Label("更多操作", systemImage: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize().labelStyle(.iconOnly)
            }
            .controlSize(.small)
            Divider()
            CaptionScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if model.captionRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("等候英文字幕").font(.title3)
                            Text("開啟 macOS Live Captions，再按「開始擷取」。首次使用請從右上角更多操作授予權限，並準備翻譯模型。")
                                .font(.callout).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    ForEach(model.captionRows) { row in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(TranscriptService.elapsedLabel(row.elapsed))
                                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                            if !settings.chineseOnly {
                                Text(row.english).font(.system(size: settings.englishFontSize)).foregroundStyle(.secondary)
                                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            }
                            if let chinese = row.chinese {
                                Text(chinese).font(.system(size: settings.chineseFontSize)).lineSpacing(4)
                                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(row.complete ? "等待翻譯…" : "等待完整句子…")
                                    .font(.callout).foregroundStyle(.tertiary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
                .textSelection(.enabled)
            }
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Text(model.connectionStatus)
                Text(model.translationStatus)
                if !model.exportStatus.isEmpty { Text(model.exportStatus) }
            }
            .font(.caption).foregroundStyle(.secondary)
            .textSelection(.enabled)
            if showsDiagnostics {
                Text(model.timingStatus).font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(model.diagnostics).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }.frame(height: 70)
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
        .onChange(of: settings.alwaysOnTop) { applyWindowSettings() }
        .onChange(of: settings.opacity) { applyWindowSettings() }
        .onChange(of: settings.appearance) { applyWindowSettings() }
        .translationTask(model.configuration) { session in
            await model.runTranslation(session: session)
        }
    }
}
