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
    @State private var showsSearch = false
    @State private var searchText = ""
    @State private var selectedSearchID: Int?
    @FocusState private var searchFocused: Bool

    private var matchingRows: [CaptionDisplayRow] { CaptionSearch.matches(model.captionRows, query: searchText) }
    private var hasQuery: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectedSearchRow: CaptionDisplayRow? {
        matchingRows.first { $0.id == selectedSearchID } ?? matchingRows.first
    }

    private func openSearch() { showsSearch = true; searchFocused = true }
    private func closeSearch() { showsSearch = false; searchFocused = false }
    private func moveSearch(_ step: Int) {
        selectedSearchID = CaptionSearch.movedID(in: matchingRows, currentID: selectedSearchRow?.id, step: step)
    }

    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard showsSearch, !term.isEmpty else { return result }
        var start = text.startIndex
        while start < text.endIndex,
              let match = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], range: start..<text.endIndex) {
            if let range = Range(match, in: result) {
                result[range].backgroundColor = .yellow.opacity(0.5)
                result[range].foregroundColor = .black
            }
            start = match.upperBound
        }
        return result
    }

    private var visibleRows: [CaptionDisplayRow] {
        if showsSearch && hasQuery { return selectedSearchRow.map { [$0] } ?? [] }
        return settings.isNotes ? model.captionRows.filter { $0.complete && $0.chinese != nil } : model.captionRows
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
                    Button("搜尋中英字幕", action: openSearch)
                    Divider()
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
            if showsSearch {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("搜尋英文或中文", text: $searchText)
                            .textFieldStyle(.roundedBorder).focused($searchFocused)
                            .onSubmit { moveSearch(1) }
                            .onExitCommand(perform: closeSearch)
                        Button { moveSearch(-1) } label: { Image(systemName: "chevron.up") }.help("上一句")
                            .disabled(matchingRows.isEmpty)
                        Button { moveSearch(1) } label: { Image(systemName: "chevron.down") }.help("下一句（Enter）")
                            .disabled(matchingRows.isEmpty)
                        Button("完成", action: closeSearch)
                    }
                    if hasQuery {
                        let index = matchingRows.firstIndex { $0.id == selectedSearchRow?.id }.map { $0 + 1 } ?? 0
                        Text("搜尋結果 \(index)／\(matchingRows.count) 句 · 顯示符合的英中對照；擷取仍繼續")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            CaptionScrollView(searching: showsSearch) {
                VStack(alignment: .leading, spacing: settings.isNotes ? 18 : 22) {
                    if visibleRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(showsSearch && hasQuery ? "找不到符合的字幕" : (settings.isNotes ? "筆記" : "等候英文字幕")).font(.title3)
                            Text(showsSearch && hasQuery ? "請換個關鍵字；搜尋會同時比對本次所有英文與中文。" : settings.isNotes ? "完成的英中對照會顯示在這裡。移到頂部可顯示操作按鈕。" : "開啟 macOS Live Captions，再按「開始擷取」。首次使用請從右上角更多操作授予權限，並準備翻譯模型。")
                                .font(.callout).foregroundStyle(.secondary)
                        }.padding(.vertical, 12)
                    }
                    ForEach(visibleRows) { row in
                        VStack(alignment: .leading, spacing: 7) {
                            if !settings.isNotes {
                                Text("[\(TranscriptService.elapsedLabel(row.elapsed))] [\(TranscriptService.clockLabel(row.timestamp))]")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                            }
                            if showsSearch || settings.isNotes || !settings.chineseOnly {
                                Text(highlighted(row.english)).font(.system(size: settings.activeEnglishSize, weight: .regular))
                                    .foregroundStyle(settings.isNotes ? Color.primary : Color.secondary)
                                    .lineSpacing(settings.isNotes ? 3 : 0)
                                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            }
                            if let chinese = row.chinese {
                                Text(highlighted(chinese)).font(.system(size: settings.activeChineseSize, weight: .regular)).lineSpacing(settings.isNotes ? 3 : 4)
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
        .onChange(of: model.searchRequest) { openSearch() }
        .onChange(of: searchText) { selectedSearchID = nil }
        .onChange(of: settings.mode) { applyWindowSettings() }
        .onChange(of: settings.activeAlwaysOnTop) { applyWindowSettings() }
        .onChange(of: settings.opacity) { applyWindowSettings() }
        .onChange(of: settings.appearance) { applyWindowSettings() }
        .translationTask(model.configuration) { session in
            await model.runTranslation(session: session)
        }
    }
}
