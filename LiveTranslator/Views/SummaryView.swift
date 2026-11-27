import SwiftUI

struct SummaryView: View {
    @Bindable var model: SummaryViewModel
    let regenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本次重點").font(.title2.bold())
                Spacer()
                Button("重新整理", action: regenerate).disabled(model.isRunning || model.isExporting)
                Button("複製") { model.copy() }.disabled(model.result == nil)
                Button("匯出 Markdown") { model.export() }.disabled(model.result == nil || model.isExporting)
            }
            if model.isRunning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(model.status).font(.callout)
                    Spacer()
                    Button("取消") { model.cancel() }
                }
            } else { Text(model.status).font(.callout).foregroundStyle(.secondary) }
            if let error = model.errorMessage { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let result = model.result {
                        Text("來源快照：\(result.capturedAt.formatted(date: .numeric, time: .standard))\n完整英文句子 \(result.sources.count) 句；略過未完成句子 \(result.omittedIncomplete) 句。")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(result.warnings, id: \.self) { warning in
                            Text(warning).font(.callout).foregroundStyle(.secondary)
                        }
                        Text("簡短摘要").font(.headline)
                        Text(result.draft.overview)
                        pointSection("主要重點", points: result.draft.keyPoints, result: result)
                        pointSection("明確待辦", points: result.draft.actionItems, result: result)
                        DisclosureGroup("查看完整英文來源") {
                            ForEach(result.sources, id: \.id) { source in
                                Text(source.line).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                            }
                        }
                    } else if !model.isRunning {
                        Text("從原始英文字幕整理繁中摘要，結果只留在記憶體，主動匯出才寫入檔案。")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.trailing, 8)
            }
            Text("AI 整理可能有誤；來源時間可用於回查，並不保證模型解讀正確。字幕會繼續擷取，新內容需按「重新整理」才納入。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 580, minHeight: 420)
    }

    private func pointSection(_ title: String, points: [SummaryPoint], result: SummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if points.isEmpty { Text("未確認到明確項目，請回查原文。").foregroundStyle(.secondary) }
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                VStack(alignment: .leading, spacing: 4) {
                    Text("• \(point.text)")
                    DisclosureGroup(result.references(point)) {
                        ForEach(Array(Set(point.sourceIDs)).sorted(), id: \.self) { id in
                            if let source = result.sources.first(where: { $0.id == id }) {
                                Text(source.text).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }.font(.caption)
                }
            }
        }
    }
}
