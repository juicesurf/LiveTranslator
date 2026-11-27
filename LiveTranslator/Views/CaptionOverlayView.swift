import SwiftUI
@preconcurrency import Translation

struct CaptionOverlayView: View {
    @Bindable var model: CaptionViewModel
    @Bindable var settings: OverlaySettings
    var showSummary: () -> Void
    var applyWindowSettings: () -> Void
    @State private var showsSettings = false
    @State private var showsDiagnostics = false
    @State private var hoveringHeader = false

    private var visibleRows: [CaptionDisplayRow] {
        settings.isNotes ? model.captionRows.filter { $0.complete && $0.chinese != nil } : model.captionRows
    }

    private var colorScheme: ColorScheme? {
        switch settings.activeAppearance {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .leading) {
                if settings.isNotes && !hoveringHeader && !showsSettings {
                    Text("筆記").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }
            HStack(spacing: 8) {
                Button(settings.isNotes ? "字幕" : "筆記", systemImage: settings.isNotes ? "captions.bubble" : "note.text") {
                    settings.mode = settings.isNotes ? .subtitles : .notes
                }.help("切換雙語字幕／雙語筆記（⌘⇧N）")
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(model.running ? "停止" : "開始擷取", systemImage: model.running ? "pause.fill" : "play.fill") {
                    if model.running { model.stop() } else { model.start() }
                }
                Button("清除", systemImage: "trash") { model.requestClearCaptions() }
                    .disabled(model.captionRows.isEmpty || model.isExporting || model.isProtectingTranscript)
                Spacer(minLength: 0)
                Button(settings.activeAlwaysOnTop ? "取消置頂" : "保持置頂", systemImage: settings.activeAlwaysOnTop ? "pin.fill" : "pin") {
                    settings.activeAlwaysOnTop.toggle()
                }.labelStyle(.iconOnly).help(settings.activeAlwaysOnTop ? "取消置頂" : "保持置頂")
                Button("顯示設定", systemImage: "textformat.size") { showsSettings.toggle() }
                    .labelStyle(.iconOnly)
                    .popover(isPresented: $showsSettings) { SettingsView(settings: settings) }
                Menu {
                    Section("儲存逐字稿") {
                        Button("儲存 TXT") { model.saveTranscript(format: .txt) }
                            .disabled(model.captionRows.isEmpty || model.isExporting || model.isProtectingTranscript)
                        Button("儲存 Markdown") { model.saveTranscript(format: .markdown) }
                            .disabled(model.captionRows.isEmpty || model.isExporting || model.isProtectingTranscript)
                    }
                    Divider()
                    Button("整理本次重點", action: showSummary)
                        .disabled(!model.captionRows.contains(where: { $0.complete }))
                    Divider()
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
            .opacity(settings.isNotes && !hoveringHeader && !showsSettings ? 0 : 1)
            .allowsHitTesting(!settings.isNotes || hoveringHeader || showsSettings)
            .accessibilityHidden(settings.isNotes && !hoveringHeader && !showsSettings)
            }
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { hoveringHeader = $0 }
            Divider()
            CaptionScrollView {
                VStack(alignment: .leading, spacing: settings.isNotes ? 18 : 22) {
                    if visibleRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(settings.isNotes ? "筆記" : "等候英文字幕").font(.title3)
                            Text(settings.isNotes ? "完成的英中對照會顯示在這裡。移到頂部可顯示操作按鈕。" : "開啟 macOS Live Captions，再按「開始擷取」。首次使用請從右上角更多操作授予權限，並準備翻譯模型。")
                                .font(.callout).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    ForEach(visibleRows) { row in
                        VStack(alignment: .leading, spacing: 7) {
                            if !settings.isNotes {
                                Text("[\(TranscriptService.elapsedLabel(row.elapsed))] [\(TranscriptService.clockLabel(row.timestamp))]")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                            }
                            if settings.isNotes || !settings.chineseOnly {
                                Text(row.english).font(.system(size: settings.activeEnglishSize, weight: .regular))
                                    .foregroundStyle(settings.isNotes ? Color.primary : Color.secondary)
                                    .lineSpacing(settings.isNotes ? 3 : 0)
                                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            }
                            if let chinese = row.chinese {
                                Text(chinese).font(.system(size: settings.activeChineseSize, weight: .regular)).lineSpacing(settings.isNotes ? 3 : 4)
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
            if !settings.isNotes {
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Text(model.connectionStatus)
                Text(model.translationStatus)
                if let changed = model.lastCaptionChangeAt {
                    Text("英文來源最後更新 \(TranscriptService.clockLabel(changed)) · 待譯 \(model.pendingTranslationCount) 句")
                }
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
        }
        .padding(16)
        .background(settings.isNotes ? Color(red: 0.97, green: 0.96, blue: 0.93) : Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
        .onChange(of: settings.mode) { applyWindowSettings() }
        .onChange(of: settings.activeAlwaysOnTop) { applyWindowSettings() }
        .onChange(of: settings.opacity) { applyWindowSettings() }
        .onChange(of: settings.appearance) { applyWindowSettings() }
        .translationTask(model.configuration) { session in
            await model.runTranslation(session: session)
        }
    }
}
