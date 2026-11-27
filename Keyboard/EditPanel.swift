import UIKit

final class EditPanel: PanelView {
    private let rowsStack = UIStackView()

    override func setup() {
        bar.addArrangedSubview(makeTitleLabel("Cursor & editing"))

        rowsStack.axis = .vertical
        rowsStack.spacing = 8
        rowsStack.distribution = .fillEqually

        rowsStack.addArrangedSubview(makeRow([
            makeButton(symbol: "arrow.left", title: nil, repeats: true) { [weak self] in self?.moveCursor(-1) },
            makeButton(symbol: "arrow.right", title: nil, repeats: true) { [weak self] in self?.moveCursor(1) },
            makeButton(symbol: nil, title: "\u{2190} word", repeats: true) { [weak self] in self?.moveWord(forward: false) },
            makeButton(symbol: nil, title: "word \u{2192}", repeats: true) { [weak self] in self?.moveWord(forward: true) }
        ]))
        rowsStack.addArrangedSubview(makeRow([
            makeButton(symbol: nil, title: "Line start", repeats: false) { [weak self] in self?.moveToLineEdge(start: true) },
            makeButton(symbol: nil, title: "Line end", repeats: false) { [weak self] in self?.moveToLineEdge(start: false) },
            makeButton(symbol: nil, title: "Del word", repeats: true) { [weak self] in self?.deleteWord() },
            makeButton(symbol: nil, title: "Del line", repeats: false) { [weak self] in self?.deleteLine() }
        ]))
        rowsStack.addArrangedSubview(makeRow([
            makeButton(symbol: nil, title: "Copy", repeats: false) { [weak self] in self?.copySelection(cut: false) },
            makeButton(symbol: nil, title: "Cut", repeats: false) { [weak self] in self?.copySelection(cut: true) },
            makeButton(symbol: nil, title: "Paste", repeats: false) { [weak self] in self?.pasteText() },
            makeButton(symbol: nil, title: "Done", repeats: false) { [weak self] in self?.host?.hostClose() }
        ]))

        let hint = UILabel()
        hint.text = "To copy or cut, first touch and hold text in the app to select it."
        hint.font = UIFont.systemFont(ofSize: 11)
        hint.textColor = UIColor.secondaryLabel
        hint.textAlignment = .center
        hint.numberOfLines = 2

        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        hint.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(rowsStack)
        body.addSubview(hint)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: body.topAnchor, constant: 4),
            rowsStack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 8),
            rowsStack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -8),
            hint.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 4),
            hint.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 8),
            hint.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -8),
            hint.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -4),
            hint.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func makeRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func makeButton(symbol: String?, title: String?, repeats: Bool, action: @escaping () -> Void) -> UIButton {
        let button = RepeatButton(type: .system)
        button.repeats = repeats
        button.onFire = action
        if let t = title {
            button.setTitle(t, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        }
        if let s = symbol {
            button.setImage(UIImage(systemName: s), for: .normal)
        }
        button.tintColor = UIColor.label
        button.setTitleColor(UIColor.label, for: .normal)
        button.backgroundColor = Theme.key
        button.layer.cornerRadius = 6
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        return button
    }

    // MARK: - Text helpers

    private func isWordChar(_ c: Character) -> Bool {
        return c.isLetter || c.isNumber
    }

    private func wordBack(in text: String) -> String {
        let chars = Array(text)
        var i = chars.count
        while i > 0 && !isWordChar(chars[i - 1]) { i -= 1 }
        while i > 0 && isWordChar(chars[i - 1]) { i -= 1 }
        return String(chars[i...])
    }

    private func wordForward(in text: String) -> String {
        let chars = Array(text)
        var i = 0
        while i < chars.count && !isWordChar(chars[i]) { i += 1 }
        while i < chars.count && isWordChar(chars[i]) { i += 1 }
        return String(chars[..<i])
    }

    // MARK: - Actions

    private func moveCursor(_ offset: Int) {
        host?.hostProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    private func moveWord(forward: Bool) {
        guard let proxy = host?.hostProxy else { return }
        if forward {
            let part = wordForward(in: proxy.documentContextAfterInput ?? "")
            if !part.isEmpty { proxy.adjustTextPosition(byCharacterOffset: part.utf16.count) }
        } else {
            let part = wordBack(in: proxy.documentContextBeforeInput ?? "")
            if !part.isEmpty { proxy.adjustTextPosition(byCharacterOffset: -part.utf16.count) }
        }
    }

    private func moveToLineEdge(start: Bool) {
        guard let proxy = host?.hostProxy else { return }
        if start {
            let line = (proxy.documentContextBeforeInput ?? "").components(separatedBy: "\n").last ?? ""
            if !line.isEmpty { proxy.adjustTextPosition(byCharacterOffset: -line.utf16.count) }
        } else {
            let line = (proxy.documentContextAfterInput ?? "").components(separatedBy: "\n").first ?? ""
            if !line.isEmpty { proxy.adjustTextPosition(byCharacterOffset: line.utf16.count) }
        }
    }

    private func deleteWord() {
        guard let proxy = host?.hostProxy else { return }
        let part = wordBack(in: proxy.documentContextBeforeInput ?? "")
        if part.isEmpty {
            proxy.deleteBackward()
        } else {
            for _ in 0..<part.count { proxy.deleteBackward() }
        }
    }

    private func deleteLine() {
        guard let proxy = host?.hostProxy else { return }
        let line = (proxy.documentContextBeforeInput ?? "").components(separatedBy: "\n").last ?? ""
        if line.isEmpty {
            proxy.deleteBackward()
        } else {
            for _ in 0..<line.count { proxy.deleteBackward() }
        }
    }

    private func copySelection(cut: Bool) {
        guard let proxy = host?.hostProxy else { return }
        guard let text = proxy.selectedText, !text.isEmpty else {
            host?.hostToast("Select some text in the app first")
            return
        }
        UIPasteboard.general.string = text
        Store.shared.addClip(text)
        if cut { proxy.deleteBackward() }
        host?.hostToast(cut ? "Cut" : "Copied")
    }

    private func pasteText() {
        guard host?.hostHasFullAccess == true else {
            host?.hostToast("Turn on Allow Full Access to paste")
            return
        }
        if let text = UIPasteboard.general.string, !text.isEmpty {
            host?.hostInsert(text)
        } else {
            host?.hostToast("Clipboard is empty")
        }
    }
}
