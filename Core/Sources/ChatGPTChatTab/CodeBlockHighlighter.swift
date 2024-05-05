import Combine
import DebounceFunction
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI

/// Use this instead of the built in ``CodeBlockView`` to highlight code blocks asynchronously,
/// so that the UI doesn't freeze when rendering large code blocks.
struct AsyncCodeBlockView: View {
    class Storage: ObservableObject {
        static let queue = DispatchQueue(
            label: "chat-code-block-highlight",
            qos: .userInteractive
        )

        @Published var highlighted: AttributedString?
        var debounceFunction: DebounceFunction<AsyncCodeBlockView>?
        
        init() {
            self.debounceFunction = .init(duration: 0.5, block: { [weak self] view in
                self?.highlight(for: view)
            })
        }

        func highlight(debounce: Bool, for view: AsyncCodeBlockView) {
            if debounce {
                Task { await debounceFunction?(view) }
            } else {
                highlight(for: view)
            }
        }
        
        func highlight(for view: AsyncCodeBlockView) {
            let content = view.content
            let language = view.fenceInfo ?? ""
            let brightMode = view.colorScheme != .dark
            let font = view.font
            Self.queue.async {
                let content = highlightedCodeBlock(
                    code: content,
                    language: language,
                    scenario: "chat",
                    brightMode: brightMode,
                    font: font
                )
                let string = AttributedString(content)
                DispatchQueue.main.async {
                    self.highlighted = string
                }
            }
        }
    }

    let fenceInfo: String?
    let content: String
    let font: NSFont

    @Environment(\.colorScheme) var colorScheme
    @StateObject var storage = Storage()
    @AppStorage(\.syncChatCodeHighlightTheme) var syncCodeHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark

    init(fenceInfo: String?, content: String, font: NSFont) {
        self.fenceInfo = fenceInfo
        self.content = content.hasSuffix("\n") ? String(content.dropLast()) : content
        self.font = font
    }

    var body: some View {
        Group {
            if let highlighted = storage.highlighted {
                Text(highlighted)
            } else {
                Text(content).font(.init(font))
            }
        }
        .onAppear {
            storage.highlight(debounce: false, for: self)
        }
        .onChange(of: colorScheme) { _ in
            storage.highlight(debounce: false, for: self)
        }
        .onChange(of: syncCodeHighlightTheme) { _ in
            storage.highlight(debounce: true, for: self)
        }
        .onChange(of: codeForegroundColorLight) { _ in
            storage.highlight(debounce: true, for: self)
        }
        .onChange(of: codeBackgroundColorLight) { _ in
            storage.highlight(debounce: true, for: self)
        }
        .onChange(of: codeForegroundColorDark) { _ in
            storage.highlight(debounce: true, for: self)
        }
        .onChange(of: codeBackgroundColorDark) { _ in
            storage.highlight(debounce: true, for: self)
        }
    }
}

