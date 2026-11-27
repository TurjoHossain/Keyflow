import UIKit

final class GIFCell: UICollectionViewCell {
    let imageView = UIImageView()
    var currentURL = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.backgroundColor = Theme.key
        pin(imageView, to: contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load(_ urlString: String, cache: NSCache<NSString, UIImage>) {
        currentURL = urlString
        let cached = cache.object(forKey: urlString as NSString)
        imageView.image = cached
        if cached != nil { return }
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            cache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                if self?.currentURL == urlString {
                    self?.imageView.image = image
                }
            }
        }.resume()
    }
}

final class GIFPanel: PanelView, UICollectionViewDataSource, UICollectionViewDelegate {
    private let segment = UISegmentedControl(items: ["Trending", "Stickers", "Recent", "\u{2605}"])
    private var collection: UICollectionView!
    private let messageLabel = UILabel()
    private let messageButton = UIButton(type: .system)
    private var items: [MediaItem] = []
    private var query = ""
    private var requestToken = 0
    private let store = Store.shared
    private let imageCache = NSCache<NSString, UIImage>()

    override func setup() {
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segment.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        bar.addArrangedSubview(segment)
        bar.addArrangedSubview(makeBarButton(symbol: "magnifyingglass", action: #selector(searchTapped)))

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 96, height: 84)
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.dataSource = self
        collection.delegate = self
        collection.register(GIFCell.self, forCellWithReuseIdentifier: "gif")
        pin(collection, to: body)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        collection.addGestureRecognizer(longPress)

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.isHidden = true
        messageButton.setTitle("Use clipboard text as Giphy API key", for: .normal)
        messageButton.addTarget(self, action: #selector(useClipboardKey), for: .touchUpInside)
        messageButton.isHidden = true

        let messageStack = UIStackView(arrangedSubviews: [messageLabel, messageButton])
        messageStack.axis = .vertical
        messageStack.spacing = 8
        messageStack.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(messageStack)
        NSLayoutConstraint.activate([
            messageStack.centerXAnchor.constraint(equalTo: body.centerXAnchor),
            messageStack.centerYAnchor.constraint(equalTo: body.centerYAnchor),
            messageStack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 20),
            messageStack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -20)
        ])

        load()
    }

    private func showMessage(_ text: String, button: Bool = false) {
        messageLabel.text = text
        messageLabel.isHidden = false
        messageButton.isHidden = !button
    }

    private func hideMessage() {
        messageLabel.isHidden = true
        messageButton.isHidden = true
    }

    @objc private func segmentChanged() {
        query = ""
        load()
    }

    @objc private func searchTapped() {
        host?.hostSearch(prompt: "Search GIFs", initial: query) { [weak self] result in
            self?.query = result
            if let current = self?.segment.selectedSegmentIndex, current > 1 { self?.segment.selectedSegmentIndex = 0 }
            self?.load()
        }
    }

    @objc private func useClipboardKey() {
        guard host?.hostHasFullAccess == true,
              let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            host?.hostToast("Copy your Giphy API key first")
            return
        }
        store.giphyKey = text
        host?.hostToast("API key saved")
        load()
    }

    private func load() {
        requestToken += 1
        let token = requestToken
        hideMessage()

        let index = segment.selectedSegmentIndex
        if index == 2 || index == 3 {
            items = (index == 2) ? store.mediaRecents : store.mediaFavorites
            collection.reloadData()
            if items.isEmpty {
                showMessage(index == 2 ? "No recent GIFs yet." : "No favorites yet. Touch and hold a GIF to favorite it.")
            }
            return
        }

        items = []
        collection.reloadData()

        guard host?.hostHasFullAccess == true else {
            showMessage("GIFs need internet access.\nTurn on Allow Full Access: Settings, General, Keyboard, Keyboards, KeyFlow.")
            return
        }
        let key = store.giphyKey
        guard !key.isEmpty else {
            showMessage("GIF search needs a free Giphy API key (developers.giphy.com). Copy the key, then tap the button.", button: true)
            return
        }

        let sticker = (index == 1)
        let path = (sticker ? "stickers" : "gifs") + "/" + (query.isEmpty ? "trending" : "search")
        guard var components = URLComponents(string: "https://api.giphy.com/v1/" + path) else { return }
        var queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "rating", value: "g")
        ]
        if !query.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query)) }
        components.queryItems = queryItems
        guard let url = components.url else { return }

        showMessage("Loading\u{2026}")
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            var result: [MediaItem] = []
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["data"] as? [[String: Any]] {
                for entry in list {
                    guard let id = entry["id"] as? String,
                          let images = entry["images"] as? [String: Any] else { continue }
                    let still = (images["fixed_width_small_still"] as? [String: Any])?["url"] as? String
                    let small = (images["fixed_width_small"] as? [String: Any])?["url"] as? String
                    let full = (images["fixed_height"] as? [String: Any])?["url"] as? String
                    if let preview = still ?? small, let link = full ?? small {
                        result.append(MediaItem(id: id, preview: preview, url: link, sticker: sticker))
                    }
                }
            }
            DispatchQueue.main.async {
                guard let self = self, token == self.requestToken else { return }
                self.items = result
                self.collection.reloadData()
                if result.isEmpty {
                    self.showMessage("No results, or the API key was rejected.")
                } else {
                    self.hideMessage()
                }
            }
        }.resume()
    }

    @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = collection.indexPathForItem(at: gesture.location(in: collection)),
              indexPath.item < items.count else { return }
        let added = store.toggleMediaFavorite(items[indexPath.item])
        host?.hostToast(added ? "Added to favorites" : "Removed from favorites")
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gif", for: indexPath)
        if let gifCell = cell as? GIFCell {
            gifCell.load(items[indexPath.item].preview, cache: imageCache)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        guard let url = URL(string: item.url) else { return }
        host?.hostToast("Copying\u{2026}")
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let data = data else {
                    self.host?.hostToast("Couldn't load that GIF")
                    return
                }
                UIPasteboard.general.setItems([["com.compuserve.gif": data]], options: [:])
                self.store.addRecentMedia(item)
                self.host?.hostToast("GIF copied. Tap and hold in the message box, then Paste.")
                self.host?.hostClose()
            }
        }.resume()
    }
}
