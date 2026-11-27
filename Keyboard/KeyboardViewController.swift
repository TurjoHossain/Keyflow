import UIKit

final class KeyboardViewController: UIInputViewController, PanelHost {

    private enum KeyLayer { case letters, numbers, symbols }
    private enum ToolbarMode { case suggestions, tools, search }
    private enum PanelKind: Int { case clipboard = 0, gif, edit, shortcuts, emoji }

    private var keyLayer: KeyLayer = .letters
    private var toolbarMode: ToolbarMode = .suggestions
    private var shifted = false
    private var capsLock = false
    private var lastShiftTap = Date.distantPast
    private var lastSpaceTap = Date.distantPast
    private var justInsertedSuggestionSpace = false
    private var lastPanX: CGFloat = 0

    private var searchActive = false
    private var searchBuffer = ""
    private var searchPrompt = ""
    private var searchCompletion: ((String) -> Void)?

    private let store = Store.shared
    private let engine = SuggestionEngine()
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private let toolbar = UIView()
    private let content = UIView()
    private let keyStack = UIStackView()
    private let toggleButton = UIButton(type: .system)
    private let suggestionStack = UIStackView()
    private let toolStack = UIStackView()
    private let searchBar = UIView()
    private let searchLabel = UILabel()
    private let preview = UILabel()
    private let toastLabel = UILabel()

    private var suggestionButtons: [UIButton] = []
    private var toolButtons: [UIButton] = []
    private var currentSuggestions: [Suggestion] = []
    private var letterKeys: [(button: UIButton, base: String)] = []
    private var shiftButton: UIButton?
    private var panel: PanelView?
    private var activePanel: PanelKind?
    private var toastToken = 0

    private let letterRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    private let numberRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"]
    ]
    private let symbolRows: [[String]] = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "\u{20AC}", "\u{00A3}", "\u{00A5}", "\u{2022}"],
        [".", ",", "?", "!", "'"]
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        buildToolbar()

        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        keyStack.axis = .vertical
        keyStack.distribution = .fillEqually
        keyStack.spacing = 11
        pin(keyStack, to: content, insets: UIEdgeInsets(top: 8, left: 3, bottom: 4, right: 3))

        preview.isHidden = true
        preview.textAlignment = .center
        preview.font = UIFont.systemFont(ofSize: 32)
        preview.textColor = UIColor.label
        preview.backgroundColor = Theme.key
        preview.layer.cornerRadius = 8
        preview.layer.masksToBounds = true
        view.addSubview(preview)

        toastLabel.isHidden = true
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        toastLabel.textColor = UIColor.white
        toastLabel.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        toastLabel.layer.cornerRadius = 12
        toastLabel.layer.masksToBounds = true
        toastLabel.numberOfLines = 2
        view.addSubview(toastLabel)

        let height = view.heightAnchor.constraint(equalToConstant: 256)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        rebuild()
        refreshToolbar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.reloadShortcuts()
        store.markKeyboardUsed()
        if hasFullAccess { haptic.prepare() }
        updateAutoShift()
        refreshSuggestions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        store.flushLearning()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if !searchActive {
            updateAutoShift()
            refreshSuggestions()
        }
    }

    // MARK: - Toolbar

    private func buildToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 40)
        ])

        toggleButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        toggleButton.tintColor = UIColor.secondaryLabel
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(toggleButton)
        NSLayoutConstraint.activate([
            toggleButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 4),
            toggleButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: 34),
            toggleButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        // Suggestions
        suggestionStack.axis = .horizontal
        suggestionStack.distribution = .fillEqually
        for i in 0..<3 {
            let b = UIButton(type: .system)
            b.tag = i
            b.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            b.titleLabel?.lineBreakMode = .byTruncatingTail
            b.setTitleColor(UIColor.label, for: .normal)
            b.setTitleColor(UIColor.clear, for: .disabled)
            b.isEnabled = false
            b.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            if i < 2 {
                let divider = UIView()
                divider.backgroundColor = UIColor.separator
                divider.translatesAutoresizingMaskIntoConstraints = false
                b.addSubview(divider)
                NSLayoutConstraint.activate([
                    divider.trailingAnchor.constraint(equalTo: b.trailingAnchor),
                    divider.centerYAnchor.constraint(equalTo: b.centerYAnchor),
                    divider.widthAnchor.constraint(equalToConstant: 1),
                    divider.heightAnchor.constraint(equalToConstant: 20)
                ])
            }
            suggestionStack.addArrangedSubview(b)
            suggestionButtons.append(b)
        }
        placeInToolbar(suggestionStack)

        // Tool strip
        toolStack.axis = .horizontal
        toolStack.distribution = .fillEqually
        let toolSymbols = ["doc.on.clipboard", "photo.on.rectangle", "character.cursor.ibeam", "bolt.fill", "face.smiling"]
        for (i, name) in toolSymbols.enumerated() {
            let b = UIButton(type: .system)
            b.tag = i
            b.setImage(UIImage(systemName: name), for: .normal)
            b.tintColor = UIColor.label
            b.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            toolStack.addArrangedSubview(b)
            toolButtons.append(b)
        }
        placeInToolbar(toolStack)

        // Search bar (used while typing into a panel's search box)
        searchLabel.font = UIFont.systemFont(ofSize: 16)
        searchLabel.lineBreakMode = .byTruncatingHead
        let clear = UIButton(type: .system)
        clear.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clear.tintColor = UIColor.secondaryLabel
        clear.addTarget(self, action: #selector(searchClearTapped), for: .touchUpInside)
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = UIColor.secondaryLabel
        icon.contentMode = .scaleAspectFit
        for v in [icon, searchLabel, clear] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            searchBar.addSubview(v)
        }
        searchBar.backgroundColor = Theme.key
        searchBar.layer.cornerRadius = 8
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            clear.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: -4),
            clear.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            clear.widthAnchor.constraint(equalToConstant: 30),
            clear.heightAnchor.constraint(equalToConstant: 30),
            searchLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            searchLabel.trailingAnchor.constraint(equalTo: clear.leadingAnchor, constant: -4),
            searchLabel.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor)
        ])
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 6),
            searchBar.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -6),
            searchBar.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 4),
            searchBar.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -4)
        ])
    }

    private func placeInToolbar(_ v: UIView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: toggleButton.trailingAnchor, constant: 2),
            v.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -4),
            v.topAnchor.constraint(equalTo: toolbar.topAnchor),
            v.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor)
        ])
    }

    private func refreshToolbar() {
        suggestionStack.isHidden = (toolbarMode != .suggestions)
        toolStack.isHidden = (toolbarMode != .tools)
        searchBar.isHidden = (toolbarMode != .search)
        toggleButton.isHidden = (toolbarMode == .search)
        let name = (toolbarMode == .tools) ? "chevron.left" : "chevron.right"
        toggleButton.setImage(UIImage(systemName: name), for: .normal)
        for (i, b) in toolButtons.enumerated() {
            b.tintColor = (activePanel?.rawValue == i) ? UIColor.systemBlue : UIColor.label
        }
    }

    @objc private func toggleTapped() {
        if panel != nil {
            closePanel()
            return
        }
        toolbarMode = (toolbarMode == .suggestions) ? .tools : .suggestions
        refreshToolbar()
        refreshSuggestions()
    }

    @objc private func toolTapped(_ sender: UIButton) {
        guard let kind = PanelKind(rawValue: sender.tag) else { return }
        if activePanel == kind {
            closePanel()
        } else {
            openPanel(kind)
        }
    }

    @objc private func emojiTapped() {
        if searchActive { return }
        openPanel(.emoji)
    }

    // MARK: - Panels

    private func openPanel(_ kind: PanelKind) {
        if searchActive { return }
        panel?.removeFromSuperview()
        let p: PanelView
        switch kind {
        case .clipboard: p = ClipboardPanel(host: self)
        case .gif: p = GIFPanel(host: self)
        case .edit: p = EditPanel(host: self)
        case .shortcuts: p = ShortcutsPanel(host: self)
        case .emoji: p = EmojiPanel(host: self)
        }
        pin(p, to: content)
        keyStack.isHidden = true
        panel = p
        activePanel = kind
        toolbarMode = .tools
        refreshToolbar()
    }

    private func closePanel() {
        panel?.removeFromSuperview()
        panel = nil
        activePanel = nil
        keyStack.isHidden = false
        toolbarMode = .suggestions
        refreshToolbar()
        store.reloadShortcuts()
        updateAutoShift()
        refreshSuggestions()
    }

    // MARK: - PanelHost

    var hostProxy: UITextDocumentProxy { return textDocumentProxy }
    var hostHasFullAccess: Bool { return hasFullAccess }

    func hostInsert(_ text: String) {
        textDocumentProxy.insertText(text)
        justInsertedSuggestionSpace = false
        updateAutoShift()
    }

    func hostBackspace() {
        textDocumentProxy.deleteBackward()
    }

    func hostClose() {
        closePanel()
    }

    func hostCaptureClipboard() {
        if hasFullAccess { store.captureFromPasteboard() }
    }

    func hostToast(_ message: String) {
        toastToken += 1
        let token = toastToken
        toastLabel.text = "  " + message + "  "
        let maxWidth = view.bounds.width - 40
        let size = toastLabel.sizeThatFits(CGSize(width: maxWidth, height: 60))
        let w = min(maxWidth, size.width + 8)
        toastLabel.frame = CGRect(x: (view.bounds.width - w) / 2, y: 150, width: w, height: max(28, size.height + 6))
        toastLabel.isHidden = false
        view.bringSubviewToFront(toastLabel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self = self, token == self.toastToken else { return }
            self.toastLabel.isHidden = true
        }
    }

    func hostSearch(prompt: String, initial: String, completion: @escaping (String) -> Void) {
        searchActive = true
        searchBuffer = initial
        searchPrompt = prompt
        searchCompletion = completion
        panel?.isHidden = true
        keyStack.isHidden = false
        keyLayer = .letters
        shifted = false
        capsLock = false
        rebuild()
        toolbarMode = .search
        refreshToolbar()
        updateSearchLabel()
    }

    private func finishSearch(cancel: Bool) {
        let result = cancel ? "" : searchBuffer
        let done = searchCompletion
        searchActive = false
        searchCompletion = nil
        searchBuffer = ""
        panel?.isHidden = false
        keyStack.isHidden = (panel != nil)
        toolbarMode = (panel != nil) ? .tools : .suggestions
        keyLayer = .letters
        rebuild()
        refreshToolbar()
        done?(result)
    }

    @objc private func searchClearTapped() {
        finishSearch(cancel: true)
    }

    private func updateSearchLabel() {
        if searchBuffer.isEmpty {
            searchLabel.text = searchPrompt
            searchLabel.textColor = UIColor.secondaryLabel
        } else {
            searchLabel.text = searchBuffer
            searchLabel.textColor = UIColor.label
        }
    }

    // MARK: - Key layout

    private func display(_ base: String) -> String {
        if keyLayer == .letters && shifted { return base.uppercased() }
        return base
    }

    private func rebuild() {
        for v in keyStack.arrangedSubviews {
            keyStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        letterKeys.removeAll()
        shiftButton = nil

        let rows: [[String]]
        switch keyLayer {
        case .letters: rows = letterRows
        case .numbers: rows = numberRows
        case .symbols: rows = symbolRows
        }

        keyStack.addArrangedSubview(typingRow(rows[0]))

        let row2 = typingRow(rows[1])
        if keyLayer == .letters {
            keyStack.addArrangedSubview(padded(row2, inset: 18))
        } else {
            keyStack.addArrangedSubview(row2)
        }

        // Row 3
        let left: UIButton
        switch keyLayer {
        case .letters:
            left = makeKey(title: nil, symbol: "shift", special: true)
            left.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
            shiftButton = left
        case .numbers:
            left = makeKey(title: "#+=", symbol: nil, special: true)
            left.addTarget(self, action: #selector(showSymbols), for: .touchUpInside)
        case .symbols:
            left = makeKey(title: "123", symbol: nil, special: true)
            left.addTarget(self, action: #selector(showNumbers), for: .touchUpInside)
        }
        let delete = RepeatButton(type: .system)
        styleKey(delete, title: nil, symbol: "delete.left", special: true)
        delete.onFire = { [weak self] in self?.deleteTapped() }

        let middle = typingRow(rows[2])
        middle.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        let row3 = UIStackView(arrangedSubviews: [left, middle, delete])
        row3.axis = .horizontal
        row3.spacing = 6
        row3.distribution = .fill
        left.widthAnchor.constraint(equalToConstant: 44).isActive = true
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true
        keyStack.addArrangedSubview(row3)

        // Row 4
        var items: [UIView] = []
        let modeKey = makeKey(title: keyLayer == .letters ? "123" : "ABC", symbol: nil, special: true)
        modeKey.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        modeKey.widthAnchor.constraint(equalToConstant: 46).isActive = true
        items.append(modeKey)

        let emoji = makeKey(title: nil, symbol: "face.smiling", special: true)
        emoji.addTarget(self, action: #selector(emojiTapped), for: .touchUpInside)
        emoji.widthAnchor.constraint(equalToConstant: 40).isActive = true
        items.append(emoji)

        if needsInputModeSwitchKey {
            let globe = makeKey(title: nil, symbol: "globe", special: true)
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            globe.widthAnchor.constraint(equalToConstant: 40).isActive = true
            items.append(globe)
        }

        let space = makeKey(title: "space", symbol: nil, special: false)
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        space.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(spacePanned(_:)))
        space.addGestureRecognizer(pan)
        items.append(space)

        let ret = makeKey(title: searchActive ? "done" : "return", symbol: nil, special: true)
        ret.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        ret.widthAnchor.constraint(equalToConstant: 86).isActive = true
        items.append(ret)

        let row4 = UIStackView(arrangedSubviews: items)
        row4.axis = .horizontal
        row4.spacing = 6
        row4.distribution = .fill
        keyStack.addArrangedSubview(row4)

        refreshShiftKey()
    }

    private func typingRow(_ bases: [String]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        for base in bases {
            let key = makeKey(title: display(base), symbol: nil, special: false)
            key.addTarget(self, action: #selector(keyDown(_:)), for: .touchDown)
            key.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            key.addTarget(self, action: #selector(keyUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            row.addArrangedSubview(key)
            if keyLayer == .letters {
                letterKeys.append((button: key, base: base))
            }
        }
        return row
    }

    private func padded(_ stack: UIStackView, inset: CGFloat) -> UIView {
        let container = UIView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset)
        ])
        return container
    }

    private func makeKey(title: String?, symbol: String?, special: Bool) -> UIButton {
        let button = UIButton(type: .system)
        styleKey(button, title: title, symbol: symbol, special: special)
        return button
    }

    @discardableResult
    private func styleKey(_ button: UIButton, title: String?, symbol: String?, special: Bool) -> UIButton {
        if let t = title {
            button.setTitle(t, for: .normal)
            let small = special || t.count > 1
            button.titleLabel?.font = UIFont.systemFont(ofSize: small ? 16 : 25, weight: small ? .regular : .light)
        }
        if let s = symbol {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
            button.setImage(UIImage(systemName: s, withConfiguration: config), for: .normal)
        }
        button.tintColor = UIColor.label
        button.setTitleColor(UIColor.label, for: .normal)
        button.backgroundColor = special ? Theme.specialKey : Theme.key
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        return button
    }

    private func refreshLetterTitles() {
        UIView.performWithoutAnimation {
            for item in letterKeys {
                item.button.setTitle(shifted ? item.base.uppercased() : item.base, for: .normal)
                item.button.layoutIfNeeded()
            }
        }
    }

    private func refreshShiftKey() {
        guard let b = shiftButton else { return }
        let name: String
        if capsLock {
            name = "capslock.fill"
        } else if shifted {
            name = "shift.fill"
        } else {
            name = "shift"
        }
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        UIView.performWithoutAnimation {
            b.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
            b.backgroundColor = shifted ? Theme.key : Theme.specialKey
            b.layoutIfNeeded()
        }
    }

    private func setShift(_ on: Bool) {
        guard shifted != on else { return }
        shifted = on
        refreshLetterTitles()
        refreshShiftKey()
    }

    // MARK: - Key press feedback

    @objc private func keyDown(_ sender: UIButton) {
        if hasFullAccess { haptic.impactOccurred() }
        guard let title = sender.currentTitle, !title.isEmpty else { return }
        let f = sender.convert(sender.bounds, to: view)
        let w = f.width * 1.45
        let h: CGFloat = 54
        var x = f.midX - w / 2
        x = max(2, min(x, view.bounds.width - w - 2))
        preview.frame = CGRect(x: x, y: f.minY - h + 8, width: w, height: h)
        preview.text = title
        preview.isHidden = false
        view.bringSubviewToFront(preview)
    }

    @objc private func keyUp() {
        preview.isHidden = true
    }

    // MARK: - Typing

    @objc private func keyTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        if searchActive {
            searchBuffer += title
            updateSearchLabel()
            if shifted && !capsLock { setShift(false) }
            return
        }
        let punctuation: Set<String> = [".", ",", "!", "?", ";", ":"]
        let proxy = textDocumentProxy
        if punctuation.contains(title) {
            commitWord(expandShortcuts: false)
            let before = proxy.documentContextBeforeInput ?? ""
            if justInsertedSuggestionSpace && before.hasSuffix(" ") {
                proxy.deleteBackward()
            }
        }
        proxy.insertText(title)
        justInsertedSuggestionSpace = false
        afterEdit()
    }

    @objc private func spaceTapped() {
        if searchActive {
            searchBuffer += " "
            updateSearchLabel()
            return
        }
        let proxy = textDocumentProxy
        let ctx = proxy.documentContextBeforeInput ?? ""
        let now = Date()
        if now.timeIntervalSince(lastSpaceTap) < 0.8,
           ctx.hasSuffix(" "), !ctx.hasSuffix("  "),
           let beforeSpace = ctx.dropLast().last,
           beforeSpace.isLetter || beforeSpace.isNumber {
            proxy.deleteBackward()
            proxy.insertText(". ")
            lastSpaceTap = Date.distantPast
            afterEdit()
            return
        }
        lastSpaceTap = now
        commitWord(expandShortcuts: true)
        proxy.insertText(" ")
        justInsertedSuggestionSpace = false
        afterEdit()
    }

    @objc private func returnTapped() {
        if searchActive {
            finishSearch(cancel: false)
            return
        }
        commitWord(expandShortcuts: true)
        textDocumentProxy.insertText("\n")
        justInsertedSuggestionSpace = false
        afterEdit()
    }

    private func deleteTapped() {
        if searchActive {
            if !searchBuffer.isEmpty {
                searchBuffer.removeLast()
                updateSearchLabel()
            }
            return
        }
        textDocumentProxy.deleteBackward()
        justInsertedSuggestionSpace = false
        afterEdit()
    }

    @objc private func shiftTapped() {
        let now = Date()
        if capsLock {
            capsLock = false
            shifted = false
        } else if now.timeIntervalSince(lastShiftTap) < 0.35 {
            capsLock = true
            shifted = true
        } else {
            shifted = !shifted
        }
        lastShiftTap = now
        refreshLetterTitles()
        refreshShiftKey()
    }

    @objc private func modeTapped() {
        keyLayer = (keyLayer == .letters) ? .numbers : .letters
        rebuild()
    }

    @objc private func showSymbols() {
        keyLayer = .symbols
        rebuild()
    }

    @objc private func showNumbers() {
        keyLayer = .numbers
        rebuild()
    }

    @objc private func spacePanned(_ gesture: UIPanGestureRecognizer) {
        if searchActive { return }
        switch gesture.state {
        case .began:
            lastPanX = 0
        case .changed:
            let x = gesture.translation(in: gesture.view).x
            let steps = Int((x - lastPanX) / 9)
            if steps != 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
                lastPanX += CGFloat(steps) * 9
            }
        default:
            break
        }
    }

    /// Learns the word just finished, and expands shortcuts when asked.
    @discardableResult
    private func commitWord(expandShortcuts: Bool) -> Bool {
        let proxy = textDocumentProxy
        if proxy.isSecureTextEntry == true { return false }
        let ctx = proxy.documentContextBeforeInput ?? ""
        let partial = SuggestionEngine.trailingWord(ctx)
        guard !partial.isEmpty else { return false }
        if expandShortcuts, let sc = store.shortcutMatching(partial) {
            for _ in 0..<partial.count { proxy.deleteBackward() }
            proxy.insertText(sc.expansion)
            return true
        }
        let head = String(ctx.dropLast(partial.count))
        store.learn(previous: engine.previousWord(in: head), word: partial)
        return false
    }

    private func afterEdit() {
        updateAutoShift()
        refreshSuggestions()
    }

    // MARK: - Auto-capitalization

    private func updateAutoShift() {
        guard keyLayer == .letters, !capsLock, !searchActive else { return }
        let proxy = textDocumentProxy
        let ctx = proxy.documentContextBeforeInput ?? ""
        var should = false
        switch proxy.autocapitalizationType ?? .sentences {
        case .none:
            should = false
        case .allCharacters:
            should = true
        case .words:
            should = ctx.isEmpty || (ctx.last?.isWhitespace ?? true)
        case .sentences:
            if ctx.isEmpty || ctx.hasSuffix("\n") {
                should = true
            } else if let last = ctx.last, last.isWhitespace {
                let trimmed = ctx.trimmingCharacters(in: .whitespacesAndNewlines)
                if let tl = trimmed.last, ".!?".contains(tl) { should = true }
            }
        @unknown default:
            should = false
        }
        setShift(should)
    }

    // MARK: - Suggestions

    private func refreshSuggestions() {
        guard toolbarMode == .suggestions else { return }
        let proxy = textDocumentProxy
        if proxy.isSecureTextEntry == true || searchActive {
            currentSuggestions = []
        } else {
            currentSuggestions = engine.suggestions(context: proxy.documentContextBeforeInput, shortcuts: store.shortcuts)
        }
        UIView.performWithoutAnimation {
            for (i, b) in suggestionButtons.enumerated() {
                if i < currentSuggestions.count {
                    b.setTitle(currentSuggestions[i].title, for: .normal)
                    b.isEnabled = true
                } else {
                    b.setTitle("", for: .normal)
                    b.isEnabled = false
                }
                b.layoutIfNeeded()
            }
        }
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        let i = sender.tag
        guard i < currentSuggestions.count else { return }
        let s = currentSuggestions[i]
        let proxy = textDocumentProxy
        let ctx = proxy.documentContextBeforeInput ?? ""

        if s.isEmoji {
            if ctx.isEmpty || ctx.hasSuffix(" ") {
                proxy.insertText(s.insert)
            } else {
                proxy.insertText(" " + s.insert)
            }
            store.recordEmoji(s.insert)
            afterEdit()
            return
        }

        let partial = SuggestionEngine.trailingWord(ctx)
        let head = String(ctx.dropLast(partial.count))
        for _ in 0..<partial.count { proxy.deleteBackward() }
        proxy.insertText(s.insert + " ")
        justInsertedSuggestionSpace = true
        if proxy.isSecureTextEntry != true {
            store.learn(previous: engine.previousWord(in: head), word: s.insert)
        }
        afterEdit()
    }
}
