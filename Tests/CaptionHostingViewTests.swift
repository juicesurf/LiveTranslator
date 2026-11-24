import AppKit
import SwiftUI
import Testing
@testable import LiveTranslatorCore

@MainActor
struct CaptionHostingViewTests {
    @Test func shrinkingWidthWrapsBothLanguagesAndIncreasesDocumentHeight() {
        let host = CaptionHostingView()
        let text = AnyView(VStack(alignment: .leading) {
            Text(Array(repeating: "A long English sentence should wrap naturally at the edge of the subtitle window.", count: 4).joined(separator: " "))
                .font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
            Text(String(repeating: "這是一段需要隨字幕視窗寬度自動換行的繁體中文內容。", count: 8))
                .font(.system(size: 23)).fixedSize(horizontal: false, vertical: true)
        })
        host.fit(text, width: 700, minimumHeight: 0)
        let wideHeight = host.frame.height
        host.fit(text, width: 300, minimumHeight: 0)
        #expect(host.frame.width == 300)
        #expect(host.frame.height > wideHeight)
        #expect(host.frame.height >= ceil(host.fittingSize.height))
        host.fit(text, width: 700, minimumHeight: 0)
        #expect(abs(host.frame.height - wideHeight) < 2)
    }
}
