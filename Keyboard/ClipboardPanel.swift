import UIKit

final class ClipCell: UITableViewCell {
    let card = UIView()
    let titleLabel = UILabel()
    let infoLabel = UILabel()
    let pinButton = UIButton(type: .system)
    let deleteButton = UIButton(type: .system)
    var onPin: (() -> Void)?
    var onDelete: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = Theme.key
        card.layer.cornerRadius = 8
        pin(card, to: contentView, insets: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))

        titleLabel.font = UIFont.systemFont(ofSize: 15)
        titleLabel.numberOfLines = 1
        titleLabel.textColor = UIColor.label
        infoLabel.font = UIFont.systemFont(ofSize: 11)
        infoLabel.textColor = UIColor.secondaryLabel

        pinButton.tintColor = UIColor.systemOrange
        deleteButton.tintColor = UIColor.systemRed
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        pinButton.addTarget(self, action: #selector(pinTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let subviewsToAdd: [UIView] = [titleLabel, infoLabel, pinButton, deleteButton]
        for v in subviewsToAdd {
            v.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(v)
        }
        NSLayoutConstraint.activate([
            deleteButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            deleteButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 34),
            deleteButton.heightAnchor.constraint(equalToConstant: 34),
            pinButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor),
            pinButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            pinButton.widthAnchor.constraint(equalToConstant: 34),
            pinButton.heightAnchor.constraint(equalToConstant: 34),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 7),
            infoLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            infoLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pinTapped() { onPin?() }
    @objc private func deleteTapped() { onDelete?() }
}

final class ClipboardPanel: PanelView, UITableViewDataSource, UITableViewDelegate {
    private let table = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var items: [Clip] = []
    private var query = ""
    private let store = Store.shared

    override func setup() {
        bar.addArrangedSubview(makeTitleLabel("Clipboard"))
        bar.addArrangedSubview(makeBarButton(symbol: "plus", action: #selector(saveCurrent)))
        bar.addArrangedSubview(makeBarButton(symbol: "magnifyingglass", action: #selector(searchTapped)))
        bar.addArrangedSubview(makeBarButton(symbol: "trash", action: #selector(clearTapped)))

        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = 54
        table.dataSource = self
        table.delegate = self
        table.register(ClipCell.self, forCellReuseIdentifier: "clip")
        pin(table, to: body)

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.systemFont(ofSize: 14)
        emptyLabel.textColor = UIColor.secondaryLabel
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: body.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: body.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -24)
        ])

        host?.hostCaptureClipboard()
        reload()
    }

    private func reload() {
        let all = store.loadClips()
        items = query.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(query) }
        table.reloadData()
        emptyLabel.isHidden = !items.isEmpty
        if all.isEmpty {
            emptyLabel.text = "Nothing here yet.\nCopy text anywhere, then open this panel (needs Allow Full Access), or tap + to save what's on your clipboard."
        } else {
            emptyLabel.text = "No matches."
        }
    }

    @objc private func saveCurrent() {
        guard host?.hostHasFullAccess == true else {
            host?.hostToast("Turn on Allow Full Access to read the clipboard")
            return
        }
        if let text = UIPasteboard.general.string, !text.isEmpty {
            store.addClip(text)
            host?.hostToast("Saved to clipboard history")
        } else {
            host?.hostToast("Clipboard has no text")
        }
        reload()
    }

    @objc private func searchTapped() {
        host?.hostSearch(prompt: "Search clipboard", initial: query) { [weak self] result in
            self?.query = result
            self?.reload()
        }
    }

    @objc private func clearTapped() {
        store.clearRecent()
        host?.hostToast("Cleared recent items (pinned kept)")
        reload()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "clip", for: indexPath)
        guard let clipCell = cell as? ClipCell else { return cell }
        let clip = items[indexPath.row]
        clipCell.titleLabel.text = clip.text.replacingOccurrences(of: "\n", with: " ")
        clipCell.infoLabel.text = store.remainingText(for: clip)
        clipCell.infoLabel.textColor = clip.pinned ? UIColor.systemOrange : UIColor.secondaryLabel
        clipCell.pinButton.setImage(UIImage(systemName: clip.pinned ? "pin.fill" : "pin"), for: .normal)
        clipCell.onPin = { [weak self] in
            self?.store.togglePin(clip.id)
            self?.reload()
        }
        clipCell.onDelete = { [weak self] in
            self?.store.deleteClip(clip.id)
            self?.reload()
        }
        return clipCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let clip = items[indexPath.row]
        host?.hostInsert(clip.text)
        host?.hostClose()
    }
}
