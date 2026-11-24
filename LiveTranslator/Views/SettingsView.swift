import SwiftUI

struct SettingsView: View {
    @Bindable var settings: OverlaySettings

    var body: some View {
        Form {
            Section("字幕視窗") {
                Toggle("保持置頂", isOn: $settings.alwaysOnTop)
                Toggle("僅顯示中文", isOn: $settings.chineseOnly)
                Picker("外觀", selection: $settings.appearance) {
                    ForEach(OverlayAppearance.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                slider("英文大小", value: $settings.englishFontSize, range: 12...30, suffix: "pt")
                slider("中文大小", value: $settings.chineseFontSize, range: 16...42, suffix: "pt")
                VStack(alignment: .leading) {
                    Text("視窗不透明度：\(Int(settings.opacity * 100))%")
                    Slider(value: $settings.opacity, in: 0.55...1, step: 0.05)
                }
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
