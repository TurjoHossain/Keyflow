import UIKit

final class ShortcutsPanel: PanelView, UITableViewDataSource, UITableViewDelegate {
    private let table = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var items: [Shortcut] = []
    private let store = Store.shared

    override func setup() {
        bar.addArrangedSubview(makeTitleLabel("Shortcuts"))
        bar.addArrangedSubview(makeBarButton(symbol: "plus", action: #selector(addTapped)))

        table.backgroundColor = .clear
        table.rowHeight = 50
        table.dataSource = self
        table.delegate = self
        pin(table, to: body)

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.systemFont(ofSize: 14)
        emptyLabel.textColor = UIColor.secondaryLabel
        emptyLabel.text = "No shortcuts yet.\nTap + to add one, e.g. omw becomes On my way!"
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: body.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: body.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -24)
        ])
        reload()
    }

    private func reload() {
        store.reloadShortcuts()
        items = store.shortcuts
        table.reloadData()
        emptyLabel.isHidden = !items.isEmpty
    }

    @objc private func addTapped() {
        host?.hostSearch(prompt: "Shortcut (e.g. omw)", initial: "") { [weak self] trigger in
            let clean = trigger.trimmingCharacters(in: .whitespaces)
            guard !clean.isEmpty, !clean.contains(" ") else { return }
            self?.host?.hostSearch(prompt: "Expands to", initial: "") { [weak self] expansion in
                guard !expansion.isEmpty else { return }
                self?.store.addShortcut(trigger: clean, expansion: expansion)
                self?.reload()
                self?.host?.hostToast("Shortcut saved")
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let item = items[indexPath.row]
        cell.backgroundColor = .clear
        cell.textLabel?.text = item.trigger
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cell.detailTextLabel?.text = item.expansion
        cell.detailTextLabel?.textColor = UIColor.secondaryLabel
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        host?.hostInsert(items[indexPath.row].expansion)
        host?.hostClose()
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.store.deleteShortcut(item.id)
            self?.reload()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
