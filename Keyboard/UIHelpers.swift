import UIKit

enum Theme {
    static let background = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.17, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
    }
    static let key = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.38, alpha: 1)
            : UIColor.white
    }
    static let specialKey = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.24, alpha: 1)
            : UIColor(red: 0.67, green: 0.70, blue: 0.73, alpha: 1)
    }
}

func pin(_ child: UIView, to parent: UIView, insets: UIEdgeInsets = .zero) {
    child.translatesAutoresizingMaskIntoConstraints = false
    parent.addSubview(child)
    NSLayoutConstraint.activate([
        child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
        child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom),
        child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
        child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right)
    ])
}

/// A button that fires immediately on touch-down and keeps firing while held.
final class RepeatButton: UIButton {
    var onFire: (() -> Void)?
    var repeats = true
    private var timer: Timer?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onFire?()
        guard repeats else { return }
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.startRepeating()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        stopTimer()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        stopTimer()
    }

    private func startRepeating() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            self?.onFire?()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

/// What a panel needs from the keyboard.
protocol PanelHost: AnyObject {
    var hostProxy: UITextDocumentProxy { get }
    var hostHasFullAccess: Bool { get }
    func hostInsert(_ text: String)
    func hostBackspace()
    func hostClose()
    func hostSearch(prompt: String, initial: String, completion: @escaping (String) -> Void)
    func hostToast(_ message: String)
    func hostCaptureClipboard()
}

/// Base class for the full-height panels (clipboard, emoji, GIFs, editing, shortcuts).
class PanelView: UIView {
    weak var host: PanelHost?
    let bar = UIStackView()
    let body = UIView()

    init(host: PanelHost) {
        self.host = host
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildChrome()
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {}

    private func buildChrome() {
        bar.axis = .horizontal
        bar.spacing = 4
        bar.alignment = .fill
        bar.distribution = .fill
        bar.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        addSubview(body)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            bar.heightAnchor.constraint(equalToConstant: 34),
            body.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 2),
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        bar.addArrangedSubview(makeBarButton(title: "ABC", width: 46, action: #selector(backTapped)))
    }

    @objc func backTapped() {
        host?.hostClose()
    }

    func makeBarButton(title: String? = nil, symbol: String? = nil, width: CGFloat = 38, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        if let t = title {
            button.setTitle(t, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        }
        if let s = symbol {
            button.setImage(UIImage(systemName: s), for: .normal)
        }
        button.tintColor = UIColor.label
        button.setTitleColor(UIColor.label, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        return button
    }

    func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        return label
    }
}
