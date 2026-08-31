import AppKit

class MainViewController: NSViewController {
    private var counter = 0
    private var items: [String] = []

    private var counterLabel: NSTextField!
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var textField: NSTextField!

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true

        let titleLabel = NSTextField(labelWithString: "Baram Motion")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 28)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        counterLabel = NSTextField(labelWithString: "カウンター: 0")
        counterLabel.font = NSFont.systemFont(ofSize: 18)
        counterLabel.alignment = .center
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(counterLabel)

        let minusButton = NSButton(title: "−", target: self, action: #selector(decrement))
        minusButton.bezelStyle = .rounded
        minusButton.font = NSFont.systemFont(ofSize: 18)
        minusButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(minusButton)

        let plusButton = NSButton(title: "+", target: self, action: #selector(increment))
        plusButton.bezelStyle = .rounded
        plusButton.font = NSFont.systemFont(ofSize: 18)
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(plusButton)

        let buttonStack = NSStackView(views: [minusButton, plusButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 16
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        let todoTitle = NSTextField(labelWithString: "TODOリスト")
        todoTitle.font = NSFont.boldSystemFont(ofSize: 16)
        todoTitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(todoTitle)

        textField = NSTextField()
        textField.placeholderString = "新しいアイテム"
        textField.bezelStyle = .roundedBezel
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)

        let addButton = NSButton(title: "追加", target: self, action: #selector(addItem))
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        let inputStack = NSStackView(views: [textField, addButton])
        inputStack.orientation = .horizontal
        inputStack.spacing = 8
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputStack)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Item"))
        column.width = 300
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let resetButton = NSButton(title: "リセット", target: self, action: #selector(reset))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resetButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            counterLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            counterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            buttonStack.topAnchor.constraint(equalTo: counterLabel.bottomAnchor, constant: 12),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            todoTitle.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 30),
            todoTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),

            inputStack.topAnchor.constraint(equalTo: todoTitle.bottomAnchor, constant: 8),
            inputStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            inputStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            scrollView.topAnchor.constraint(equalTo: inputStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -20),

            resetButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func increment() {
        counter += 1
        updateCounter()
    }

    @objc private func decrement() {
        counter -= 1
        updateCounter()
    }

    private func updateCounter() {
        counterLabel.stringValue = "カウンター: \(counter)"
    }

    @objc private func addItem() {
        let text = textField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        items.append(text)
        textField.stringValue = ""
        tableView.reloadData()
    }

    @objc private func reset() {
        counter = 0
        items.removeAll()
        updateCounter()
        tableView.reloadData()
    }
}

extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: items[row])
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }
}
