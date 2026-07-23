import Cocoa
import UniformTypeIdentifiers

private enum WizardStep: Int, CaseIterable {
    case intro
    case hsmod
    case bepinex
    case hearthstone
    case install
}

private final class DropFieldView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let chooseButton = NSButton(title: "从 Finder 选择", target: nil, action: nil)

    var onChoose: (() -> Void)?
    var onDropPath: ((String) -> Void)?

    var representedPath: String = "" {
        didSet { updateDetail() }
    }

    init(title: String, placeholder: String) {
        super.init(frame: .zero)
        setup(title: title, placeholder: placeholder)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(title: "", placeholder: "")
    }

    private func setup(title: String, placeholder: String) {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        registerForDraggedTypes([.fileURL])

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        detailLabel.stringValue = placeholder
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.isSelectable = true

        chooseButton.target = self
        chooseButton.action = #selector(chooseClicked)
        chooseButton.bezelStyle = .rounded

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(chooseButton)

        stack.addArrangedSubview(row)
        stack.addArrangedSubview(detailLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 112),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            chooseButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func updateDetail() {
        detailLabel.stringValue = representedPath.isEmpty ? "把 zip、文件夹或 app 拖到这里" : representedPath
        detailLabel.textColor = representedPath.isEmpty ? .secondaryLabelColor : .labelColor
    }

    @objc private func chooseClicked() {
        onChoose?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard draggedFilePath(sender) != nil else { return [] }
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        guard let path = draggedFilePath(sender) else { return false }
        onDropPath?(path)
        return true
    }

    private func draggedFilePath(_ sender: NSDraggingInfo) -> String? {
        guard let item = sender.draggingPasteboard.pasteboardItems?.first,
              let value = item.string(forType: .fileURL),
              let url = URL(string: value) else {
            return nil
        }
        return url.path
    }
}

final class InstallerController: NSObject, NSApplicationDelegate {
    private let hsmodRepoURL = "https://github.com/Pik-4/HsMod"
    private let hsmodArchiveURL = "https://github.com/Pik-4/HsMod/archive/refs/heads/bepinex5.zip"
    private let bepinexReleasesURL = "https://github.com/BepInEx/BepInEx/releases"
    private let guiPath = "/usr/local/share/dotnet:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )

    private let contentStack = NSStackView()
    private let statusLabel = NSTextField(labelWithString: "准备就绪")
    private let progress = NSProgressIndicator()
    private let backButton = NSButton(title: "上一步", target: nil, action: nil)
    private let primaryButton = NSButton(title: "下一步", target: nil, action: nil)
    private let reinjectButton = NSButton(title: "重新注入", target: nil, action: nil)
    private let openPackButton = NSButton(title: "打开 /pack", target: nil, action: nil)
    private let logView = NSTextView()

    private var step: WizardStep = .intro
    private var hsmodPath = ""
    private var bepinexPath = ""
    private var hearthstonePath = ""
    private var currentProcess: Process?

    private var isBusy: Bool {
        currentProcess != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        prefillDefaults()
        buildWindow()
        render()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildWindow() {
        window.title = "HsMod macOS Installer"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 780, height: 560)

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 18, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        root.addArrangedSubview(headerView())

        contentStack.orientation = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(contentStack)

        root.addArrangedSubview(footerView())

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            contentStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 390)
        ])
    }

    private func headerView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.alignment = .centerY

        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        }

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 4

        let title = NSTextField(labelWithString: "HsMod macOS Installer")
        title.font = .systemFont(ofSize: 26, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "按步骤下载、拖入文件，然后注入到 macOS 炉石。")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 13)

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64)
        ])

        return stack
    }

    private func footerView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY

        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.bezelStyle = .rounded

        primaryButton.target = self
        primaryButton.action = #selector(primaryAction)
        primaryButton.bezelStyle = .rounded

        reinjectButton.target = self
        reinjectButton.action = #selector(reinject)
        reinjectButton.bezelStyle = .rounded

        openPackButton.target = self
        openPackButton.action = #selector(openPack)
        openPackButton.bezelStyle = .rounded

        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(backButton)
        stack.addArrangedSubview(reinjectButton)
        stack.addArrangedSubview(openPackButton)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(progress)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(primaryButton)

        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 92),
            primaryButton.widthAnchor.constraint(equalToConstant: 116),
            reinjectButton.widthAnchor.constraint(equalToConstant: 100),
            openPackButton.widthAnchor.constraint(equalToConstant: 100)
        ])

        return stack
    }

    private func render() {
        clear(contentStack)

        statusLabel.stringValue = !isBusy ? "第 \(step.rawValue + 1) / \(WizardStep.allCases.count) 步" : statusLabel.stringValue
        backButton.isEnabled = !isBusy && step.rawValue > 0
        primaryButton.isEnabled = !isBusy
        reinjectButton.isHidden = step != .install
        openPackButton.isHidden = step != .install
        primaryButton.title = step == .install ? "开始安装" : "下一步"

        switch step {
        case .intro:
            renderIntro()
        case .hsmod:
            renderHsMod()
        case .bepinex:
            renderBepInEx()
        case .hearthstone:
            renderHearthstone()
        case .install:
            renderInstall()
        }
    }

    private func renderIntro() {
        contentStack.addArrangedSubview(pageTitle("先准备三个文件"))
        contentStack.addArrangedSubview(paragraph("这个向导会一步步带你完成：从 GitHub 下载 HsMod bepinex5 源码 zip、下载 BepInEx 5 macOS universal zip、选择 Hearthstone.app，然后安装器会自动构建 patched HsMod.dll 并注入到炉石。"))
        contentStack.addArrangedSubview(paragraph("如果以后炉石更新或 Battle.net 把启动文件恢复了，回到最后一步点“重新注入”即可。"))
        contentStack.addArrangedSubview(fillView())
    }

    private func renderHsMod() {
        contentStack.addArrangedSubview(pageTitle("下载并选择 HsMod"))
        contentStack.addArrangedSubview(paragraph("需要 HsMod 的 bepinex5 分支源码 zip。点下面的链接从 GitHub 下载最新源码；如果你已经有源码 zip，也可以直接拖进来。"))
        contentStack.addArrangedSubview(linkRow(urlString: hsmodArchiveURL, buttons: [
            ("下载源码 zip", { [weak self] in self?.openURL(self?.hsmodArchiveURL) }),
            ("打开 GitHub", { [weak self] in self?.openURL(self?.hsmodRepoURL) })
        ]))

        let drop = DropFieldView(title: "拖入 HsMod 源码 zip", placeholder: "也可以拖入解压后的 HsMod 源码文件夹")
        drop.representedPath = hsmodPath
        drop.onChoose = { [weak self] in self?.chooseHsMod() }
        drop.onDropPath = { [weak self] path in
            self?.hsmodPath = self?.expandedPath(path) ?? path
            self?.render()
        }
        contentStack.addArrangedSubview(drop)
        contentStack.addArrangedSubview(fillView())
    }

    private func renderBepInEx() {
        contentStack.addArrangedSubview(pageTitle("下载并选择 BepInEx"))
        contentStack.addArrangedSubview(paragraph("需要 BepInEx 5 的 macOS universal zip。点下面的 Releases 链接，下载最新的 macOS universal zip；如果你已经有 zip，也可以直接拖进来。"))
        contentStack.addArrangedSubview(linkRow(urlString: bepinexReleasesURL, buttons: [
            ("打开 Releases", { [weak self] in self?.openURL(self?.bepinexReleasesURL) })
        ]))

        let drop = DropFieldView(title: "拖入 BepInEx macOS universal zip", placeholder: "不要把这个 zip 放到 HsMod 那一步")
        drop.representedPath = bepinexPath
        drop.onChoose = { [weak self] in self?.chooseBepInEx() }
        drop.onDropPath = { [weak self] path in
            self?.bepinexPath = self?.expandedPath(path) ?? path
            self?.render()
        }
        contentStack.addArrangedSubview(drop)
        contentStack.addArrangedSubview(fillView())
    }

    private func renderHearthstone() {
        contentStack.addArrangedSubview(pageTitle("选择炉石安装位置"))
        contentStack.addArrangedSubview(paragraph("选择 Hearthstone.app，或者直接选择 /Applications/Hearthstone 文件夹。安装前请先退出炉石。"))

        let drop = DropFieldView(title: "拖入 Hearthstone.app", placeholder: "默认位置是 /Applications/Hearthstone/Hearthstone.app")
        drop.representedPath = hearthstonePath
        drop.onChoose = { [weak self] in self?.chooseHearthstone() }
        drop.onDropPath = { [weak self] path in
            self?.hearthstonePath = self?.normalizedHearthstonePath(path) ?? path
            self?.render()
        }
        contentStack.addArrangedSubview(drop)
        contentStack.addArrangedSubview(fillView())
    }

    private func renderInstall() {
        contentStack.addArrangedSubview(pageTitle("确认并安装"))
        contentStack.addArrangedSubview(summaryRow("HsMod", hsmodPath))
        contentStack.addArrangedSubview(summaryRow("BepInEx", bepinexPath))
        contentStack.addArrangedSubview(summaryRow("Hearthstone", hearthstonePath))

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.textContainerInset = NSSize(width: 8, height: 8)
        scroll.documentView = logView
        contentStack.addArrangedSubview(scroll)

        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true
    }

    private func pageTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        return label
    }

    private func paragraph(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 760
        return label
    }

    private func linkRow(urlString: String, buttons: [(String, () -> Void)]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY

        let field = NSTextField(labelWithString: urlString)
        field.isSelectable = true
        field.lineBreakMode = .byTruncatingMiddle
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.textColor = .secondaryLabelColor

        stack.addArrangedSubview(field)
        for button in buttons {
            let nsButton = ClosureButton(title: button.0, action: button.1)
            nsButton.bezelStyle = .rounded
            nsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
            stack.addArrangedSubview(nsButton)
        }

        return stack
    }

    private func summaryRow(_ label: String, _ value: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY

        let name = NSTextField(labelWithString: label)
        name.textColor = .secondaryLabelColor
        name.alignment = .right
        name.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let path = NSTextField(labelWithString: value)
        path.isSelectable = true
        path.lineBreakMode = .byTruncatingMiddle

        stack.addArrangedSubview(name)
        stack.addArrangedSubview(path)
        return stack
    }

    private func fillView() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    private func clear(_ stack: NSStackView) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func prefillDefaults() {
        for candidate in downloadsCandidates(containing: ["hsmod"]) {
            if hsmodSourceLooksValid(candidate) {
                hsmodPath = candidate
                break
            }
        }

        for candidate in downloadsCandidates(containing: ["bepinex"]) {
            if bepinexZipLooksValid(candidate) {
                bepinexPath = candidate
                break
            }
        }

        let hearthstone = "/Applications/Hearthstone/Hearthstone.app"
        if FileManager.default.fileExists(atPath: hearthstone) {
            hearthstonePath = hearthstone
        }
    }

    @objc private func goBack() {
        guard currentProcess == nil, step.rawValue > 0 else { return }
        step = WizardStep(rawValue: step.rawValue - 1) ?? .intro
        render()
    }

    @objc private func primaryAction() {
        guard currentProcess == nil else { return }

        if step == .install {
            install()
            return
        }

        guard validateCurrentStep() else { return }
        step = WizardStep(rawValue: step.rawValue + 1) ?? .install
        render()
    }

    private func validateCurrentStep() -> Bool {
        switch step {
        case .intro:
            return true
        case .hsmod:
            return validateHsMod()
        case .bepinex:
            return validateBepInEx()
        case .hearthstone:
            return validateHearthstone()
        case .install:
            return validateAllInputs()
        }
    }

    private func validateHsMod() -> Bool {
        hsmodPath = expandedPath(hsmodPath)
        guard FileManager.default.fileExists(atPath: hsmodPath) else {
            showAlert("请选择 HsMod 源码 zip，或者包含 HsMod/HsMod.csproj 的源码文件夹。")
            return false
        }
        guard hsmodSourceLooksValid(hsmodPath) else {
            if bepinexZipLooksValid(hsmodPath) {
                showAlert("这里选成了 BepInEx。请在这一步选择 HsMod 源码 zip。")
            } else {
                showAlert("这个文件不是可用的 HsMod 源码包。需要能找到 HsMod/HsMod.csproj。")
            }
            return false
        }
        return true
    }

    private func validateBepInEx() -> Bool {
        bepinexPath = expandedPath(bepinexPath)
        guard FileManager.default.fileExists(atPath: bepinexPath) else {
            showAlert("请选择 BepInEx 5 macOS universal zip。")
            return false
        }
        guard bepinexZipLooksValid(bepinexPath) else {
            if hsmodSourceLooksValid(bepinexPath) {
                showAlert("这里选成了 HsMod。请在这一步选择 BepInEx 5 macOS universal zip。")
            } else {
                showAlert("这个文件不是可用的 BepInEx macOS zip。需要能找到 libdoorstop.dylib。")
            }
            return false
        }
        return true
    }

    private func validateHearthstone() -> Bool {
        hearthstonePath = normalizedHearthstonePath(hearthstonePath)
        guard FileManager.default.fileExists(atPath: hearthstonePath) else {
            showAlert("请选择 Hearthstone.app，或者 /Applications/Hearthstone 文件夹。")
            return false
        }
        return true
    }

    private func validateAllInputs() -> Bool {
        guard validateHsMod(), validateBepInEx(), validateHearthstone() else {
            return false
        }

        if hsmodPath == bepinexPath {
            showAlert("HsMod 和 BepInEx 不能是同一个 zip。")
            return false
        }

        return true
    }

    @objc private func chooseHsMod() {
        let panel = NSOpenPanel()
        panel.title = "选择 HsMod 源码 zip 或源码文件夹"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            hsmodPath = expandedPath(url.path)
            render()
        }
    }

    @objc private func chooseBepInEx() {
        let panel = NSOpenPanel()
        panel.title = "选择 BepInEx 5 macOS universal zip"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            bepinexPath = expandedPath(url.path)
            render()
        }
    }

    @objc private func chooseHearthstone() {
        let panel = NSOpenPanel()
        panel.title = "选择 Hearthstone.app 或 Hearthstone 文件夹"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            hearthstonePath = normalizedHearthstonePath(url.path)
            render()
        }
    }

    @objc private func openPack() {
        NSWorkspace.shared.open(URL(string: "http://127.0.0.1:58744/pack")!)
    }

    private func install() {
        guard validateAllInputs() else { return }
        logView.string = ""
        appendLog("Starting install...\n")
        runBundledScript(
            "install_from_archives.sh",
            environment: installerEnvironment(),
            busyTitle: "安装中"
        ) { [weak self] ok in
            if ok {
                self?.statusLabel.stringValue = "安装完成"
                self?.appendLog("\n安装完成。现在从 Battle.net 启动炉石。\n")
                self?.openBattleNet()
            }
        }
    }

    @objc private func reinject() {
        guard validateHearthstone() else { return }
        logView.string = ""
        appendLog("Re-injecting current install...\n")
        runBundledScript(
            "reinject_current_install.sh",
            environment: [
                "HEARTHSTONE_APP": hearthstonePath,
                "HSMOD_NO_ALERT": "1"
            ],
            busyTitle: "重新注入中"
        ) { [weak self] ok in
            if ok {
                self?.statusLabel.stringValue = "重新注入完成"
                self?.appendLog("\n重新注入完成。现在从 Battle.net 启动炉石。\n")
                self?.openBattleNet()
            }
        }
    }

    private func installerEnvironment() -> [String: String] {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HsMod macOS Installer", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return [
            "HSMOD_SOURCE": hsmodPath,
            "BEPINEX_ZIP": bepinexPath,
            "HEARTHSTONE_APP": hearthstonePath,
            "HSMOD_WORK_ROOT": support.appendingPathComponent("build", isDirectory: true).path,
            "HSMOD_NO_ALERT": "1"
        ]
    }

    private func runBundledScript(
        _ scriptName: String,
        environment extraEnvironment: [String: String],
        busyTitle: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard currentProcess == nil else { return }
        guard let resourcesURL = Bundle.main.resourceURL else {
            showAlert("Cannot locate app resources.")
            return
        }

        let scriptURL = resourcesURL.appendingPathComponent("scripts").appendingPathComponent(scriptName)
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            showAlert("Missing script: \(scriptName)")
            return
        }

        setBusy(true, title: busyTitle)

        let process = Process()
        currentProcess = process
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = resourcesURL

        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"] ?? ""
        environment["PATH"] = inheritedPath.isEmpty ? guiPath : "\(guiPath):\(inheritedPath)"
        if environment["DOTNET_ROOT"] == nil, FileManager.default.fileExists(atPath: "/usr/local/share/dotnet/dotnet") {
            environment["DOTNET_ROOT"] = "/usr/local/share/dotnet"
        }
        extraEnvironment.forEach { environment[$0.key] = $0.value }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.currentProcess = nil
                let ok = finished.terminationStatus == 0
                self?.setBusy(false, title: ok ? "准备就绪" : "失败")
                self?.appendLog("\nProcess exited with status \(finished.terminationStatus).\n")
                if !ok {
                    self?.showAlert("执行失败。请看最后一步里的日志。")
                }
                completion(ok)
            }
        }

        do {
            try process.run()
        } catch {
            currentProcess = nil
            setBusy(false, title: "失败")
            showAlert(error.localizedDescription)
        }
    }

    private func setBusy(_ busy: Bool, title: String) {
        backButton.isEnabled = !busy && step.rawValue > 0
        primaryButton.isEnabled = !busy
        reinjectButton.isEnabled = !busy
        openPackButton.isEnabled = !busy
        statusLabel.stringValue = title
        busy ? progress.startAnimation(nil) : progress.stopAnimation(nil)
    }

    private func appendLog(_ text: String) {
        let end = NSRange(location: logView.string.count, length: 0)
        logView.textStorage?.replaceCharacters(in: end, with: text)
        logView.scrollToEndOfDocument(nil)
    }

    private func normalizedHearthstonePath(_ rawPath: String) -> String {
        let path = expandedPath(rawPath)
        if path.hasSuffix(".app") {
            return path
        }
        return URL(fileURLWithPath: path).appendingPathComponent("Hearthstone.app").path
    }

    private func expandedPath(_ rawPath: String) -> String {
        NSString(string: rawPath.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
    }

    private func downloadsCandidates(containing needles: [String]) -> [String] {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { url in
                let name = url.lastPathComponent.lowercased()
                return needles.allSatisfy { name.contains($0) }
            }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }
            .map(\.path)
    }

    private func hsmodSourceLooksValid(_ path: String) -> Bool {
        pathContains(path, suffixes: ["HsMod/HsMod.csproj"])
    }

    private func bepinexZipLooksValid(_ path: String) -> Bool {
        pathContains(path, suffixes: ["libdoorstop.dylib"])
    }

    private func pathContains(_ path: String, suffixes: [String]) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }

        if isDirectory.boolValue {
            return directoryContains(path, suffixes: suffixes)
        }

        guard path.lowercased().hasSuffix(".zip") else {
            return false
        }

        return zipContains(path, suffixes: suffixes)
    }

    private func directoryContains(_ path: String, suffixes: [String]) -> Bool {
        let root = URL(fileURLWithPath: path)
        for suffix in suffixes {
            if FileManager.default.fileExists(atPath: root.appendingPathComponent(suffix).path) {
                return true
            }
        }

        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return false
        }

        for case let item as String in enumerator {
            if suffixes.contains(where: { item == $0 || item.hasSuffix("/\($0)") }) {
                return true
            }
        }

        return false
    }

    private func zipContains(_ path: String, suffixes: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z", "-1", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return false
        }

        return text.split(separator: "\n").contains { entry in
            suffixes.contains { suffix in
                entry == suffix || entry.hasSuffix("/\(suffix)")
            }
        }
    }

    private func openURL(_ value: String?) {
        guard let value, let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openBattleNet() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Battle.net.app"))
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "HsMod macOS Installer"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

private final class ClosureButton: NSButton {
    private let closure: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.closure = action
        super.init(frame: .zero)
        self.title = title
        target = self
        self.action = #selector(runClosure)
    }

    required init?(coder: NSCoder) {
        self.closure = {}
        super.init(coder: coder)
    }

    @objc private func runClosure() {
        closure()
    }
}

let app = NSApplication.shared
let delegate = InstallerController()
app.delegate = delegate
app.run()
