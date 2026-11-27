import SwiftUI

struct SettingsView: View {
    @Bindable var settings: OverlaySettings

    var body: some View {
        Form {
            Picker("模式", selection: $settings.mode) {
                ForEach(OverlayMode.allCases) { Text($0.title).tag($0) }
            }
            if settings.isNotes {
                Text("筆記模式使用淺色背景、英中皆為 14pt 一般字重，僅顯示已完成的英中對照。切回字幕模式會恢復原本設定。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("字幕視窗") {
                Toggle("保持置頂", isOn: $settings.activeAlwaysOnTop)
                Toggle("僅顯示中文", isOn: $settings.chineseOnly).disabled(settings.isNotes)
                Picker("外觀", selection: $settings.appearance) {
                    ForEach(OverlayAppearance.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .disabled(settings.isNotes)
                slider("英文大小", value: $settings.englishFontSize, range: 12...30, suffix: "pt").disabled(settings.isNotes)
                slider("中文大小", value: $settings.chineseFontSize, range: 16...42, suffix: "pt").disabled(settings.isNotes)
                VStack(alignment: .leading) {
                    Text("視窗不透明度：\(Int(settings.opacity * 100))%")
                    Slider(value: $settings.opacity, in: 0.55...1, step: 0.05)
                }.disabled(settings.isNotes)
            }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 440)
        .padding(8)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(title)：\(Int(value.wrappedValue)) \(suffix)")
            Slider(value: value, in: range, step: 1)
        }
    }
}
