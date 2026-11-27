import UIKit

final class EmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = UIFont.systemFont(ofSize: 28)
        label.textAlignment = .center
        pin(label, to: contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class EmojiPanel: PanelView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collection: UICollectionView!
    private let tabStack = UIStackView()
    private var tabButtons: [UIButton] = []
    private var items: [String] = []
    private var selectedTab = 2
    private let store = Store.shared
    private let searchButton = UIButton(type: .system)

    override func setup() {
        searchButton.setTitle("  Search emoji", for: .normal)
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        searchButton.contentHorizontalAlignment = .left
        searchButton.tintColor = UIColor.secondaryLabel
        searchButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        searchButton.backgroundColor = Theme.key
        searchButton.layer.cornerRadius = 8
        searchButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        searchButton.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        bar.addArrangedSubview(searchButton)

        let delete = RepeatButton(type: .system)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        delete.tintColor = UIColor.label
        delete.widthAnchor.constraint(equalToConstant: 40).isActive = true
        delete.onFire = { [weak self] in self?.host?.hostBackspace() }
        bar.addArrangedSubview(delete)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 40, height: 42)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.dataSource = self
        collection.delegate = self
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: "emoji")
        collection.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(collection)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        collection.addGestureRecognizer(longPress)

        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.spacing = 2
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(tabStack)

        var icons: [String] = ["\u{1F552}", "\u{2B50}"]
        for category in EmojiData.categories { icons.append(category.icon) }
        for (index, icon) in icons.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(icon, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            button.layer.cornerRadius = 6
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
            tabButtons.append(button)
        }

        NSLayoutConstraint.activate([
            tabStack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 6),
            tabStack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -6),
            tabStack.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -4),
            tabStack.heightAnchor.constraint(equalToConstant: 32),
            collection.topAnchor.constraint(equalTo: body.topAnchor),
            collection.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: tabStack.topAnchor, constant: -2)
        ])

        selectTab(store.emojiRecents.isEmpty ? 2 : 0)
    }

    private func selectTab(_ index: Int) {
        selectedTab = index
        switch index {
        case 0: items = store.emojiRecents
        case 1: items = store.emojiFavorites
        default: items = EmojiData.categories[index - 2].emojis
        }
        for (i, b) in tabButtons.enumerated() {
            b.backgroundColor = (i == index) ? Theme.key : UIColor.clear
        }
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        selectTab(sender.tag)
    }

    @objc private func searchTapped() {
        host?.hostSearch(prompt: "Search emoji", initial: "") { [weak self] query in
            guard let self = self else { return }
            if query.isEmpty {
                self.selectTab(self.selectedTab)
            } else {
                self.items = EmojiData.search(query)
                for b in self.tabButtons { b.backgroundColor = UIColor.clear }
                self.collection.reloadData()
                if self.items.isEmpty { self.host?.hostToast("No emoji found") }
            }
        }
    }

    @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = collection.indexPathForItem(at: gesture.location(in: collection)),
              indexPath.item < items.count else { return }
        let emoji = items[indexPath.item]
        let added = store.toggleEmojiFavorite(emoji)
        host?.hostToast(added ? "\(emoji) added to favorites" : "\(emoji) removed from favorites")
        if selectedTab == 1 { selectTab(1) }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath)
        if let emojiCell = cell as? EmojiCell {
            emojiCell.label.text = items[indexPath.item]
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = items[indexPath.item]
        store.recordEmoji(emoji)
        host?.hostInsert(emoji)
    }
}
