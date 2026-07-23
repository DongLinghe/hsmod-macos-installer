import Cocoa
import UniformTypeIdentifiers

final class InstallerController: NSObject, NSApplicationDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )

    private let hsmodField = NSTextField()
    private let bepinexField = NSTextField()
    private let hearthstoneField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let logView = NSTextView()
    private let progress = NSProgressIndicator()
    private let installButton = NSButton(title: "Install", target: nil, action: nil)
    private let reinjectButton = NSButton(title: "Re-inject", target: nil, action: nil)
    private let openPackButton = NSButton(title: "Open /pack", target: nil, action: nil)
    private let guiPath = "/usr/local/share/dotnet:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    private var currentProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        prefillDefaults()
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

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let title = NSTextField(labelWithString: "HsMod macOS Installer")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(title)

        root.addArrangedSubview(row(label: "HsMod", field: hsmodField, buttonTitle: "Choose...", action: #selector(chooseHsMod)))
        root.addArrangedSubview(row(label: "BepInEx", field: bepinexField, buttonTitle: "Choose...", action: #selector(chooseBepInEx)))
        root.addArrangedSubview(row(label: "Hearthstone", field: hearthstoneField, buttonTitle: "Choose...", action: #selector(chooseHearthstone)))

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.spacing = 10
        actionRow.translatesAutoresizingMaskIntoConstraints = false

        installButton.target = self
        installButton.action = #selector(install)
        installButton.bezelStyle = .rounded

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

        actionRow.addArrangedSubview(installButton)
        actionRow.addArrangedSubview(reinjectButton)
        actionRow.addArrangedSubview(openPackButton)
        actionRow.addArrangedSubview(progress)
        actionRow.addArrangedSubview(statusLabel)
        root.addArrangedSubview(actionRow)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.textContainerInset = NSSize(width: 8, height: 8)
        scroll.documentView = logView
        root.addArrangedSubview(scroll)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            installButton.widthAnchor.constraint(equalToConstant: 96),
            reinjectButton.widthAnchor.constraint(equalToConstant: 96),
            openPackButton.widthAnchor.constraint(equalToConstant: 96)
        ])
    }

    private func row(label: String, field: NSTextField, buttonTitle: String, action: Selector) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.textColor = .secondaryLabelColor
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 92).isActive = true

        field.isEditable = false
        field.isSelectable = true
        field.placeholderString = "Not selected"
        field.lineBreakMode = .byTruncatingMiddle

        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 96).isActive = true

        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(field)
        stack.addArrangedSubview(button)
        return stack
    }

    private func prefillDefaults() {
        let downloadsBepInEx = NSString(string: "~/Downloads/BepInEx_macos_universal_5.4.23.5.zip").expandingTildeInPath
        if FileManager.default.fileExists(atPath: downloadsBepInEx) {
            bepinexField.stringValue = downloadsBepInEx
        }

        let hearthstone = "/Applications/Hearthstone/Hearthstone.app"
        if FileManager.default.fileExists(atPath: hearthstone) {
            hearthstoneField.stringValue = hearthstone
        }
    }

    @objc private func chooseHsMod() {
        let panel = NSOpenPanel()
        panel.title = "Choose HsMod source or zip"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            hsmodField.stringValue = url.path
        }
    }

    @objc private func chooseBepInEx() {
        let panel = NSOpenPanel()
        panel.title = "Choose BepInEx macOS zip"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            bepinexField.stringValue = url.path
        }
    }

    @objc private func chooseHearthstone() {
        let panel = NSOpenPanel()
        panel.title = "Choose Hearthstone.app or Hearthstone folder"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            hearthstoneField.stringValue = normalizedHearthstonePath(url.path)
        }
    }

    @objc private func install() {
        guard validateInstallInputs() else { return }
        appendLog("Starting install...\n")
        runBundledScript(
            "install_from_archives.sh",
            environment: installerEnvironment(),
            busyTitle: "Installing"
        ) { [weak self] ok in
            if ok {
                self?.statusLabel.stringValue = "Installed"
                self?.appendLog("\nInstalled. Launch Hearthstone from Battle.net now.\n")
                self?.openBattleNet()
            }
        }
    }

    @objc private func reinject() {
        let hearthstone = normalizedHearthstonePath(hearthstoneField.stringValue)
        guard FileManager.default.fileExists(atPath: hearthstone) else {
            showAlert("Choose Hearthstone.app first.")
            return
        }
        appendLog("Re-injecting current install...\n")
        runBundledScript(
            "reinject_current_install.sh",
            environment: [
                "HEARTHSTONE_APP": hearthstone,
                "HSMOD_NO_ALERT": "1"
            ],
            busyTitle: "Re-injecting"
        ) { [weak self] ok in
            if ok {
                self?.statusLabel.stringValue = "Re-injected"
                self?.appendLog("\nRe-injected. Launch Hearthstone from Battle.net now.\n")
                self?.openBattleNet()
            }
        }
    }

    @objc private func openPack() {
        NSWorkspace.shared.open(URL(string: "http://127.0.0.1:58744/pack")!)
    }

    private func validateInstallInputs() -> Bool {
        guard FileManager.default.fileExists(atPath: hsmodField.stringValue) else {
            showAlert("Choose HsMod source or zip.")
            return false
        }
        guard FileManager.default.fileExists(atPath: bepinexField.stringValue) else {
            showAlert("Choose BepInEx_macos_universal_5.4.23.5.zip.")
            return false
        }
        let hearthstone = normalizedHearthstonePath(hearthstoneField.stringValue)
        guard FileManager.default.fileExists(atPath: hearthstone) else {
            showAlert("Choose Hearthstone.app.")
            return false
        }
        hearthstoneField.stringValue = hearthstone
        return true
    }

    private func installerEnvironment() -> [String: String] {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HsMod macOS Installer", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return [
            "HSMOD_SOURCE": hsmodField.stringValue,
            "BEPINEX_ZIP": bepinexField.stringValue,
            "HEARTHSTONE_APP": normalizedHearthstonePath(hearthstoneField.stringValue),
            "HSMOD_WORK_ROOT": support.appendingPathComponent("build", isDirectory: true).path,
            "HSMOD_NO_ALERT": "1"
        ]
    }

    private func normalizedHearthstonePath(_ rawPath: String) -> String {
        let path = NSString(string: rawPath).expandingTildeInPath
        if path.hasSuffix(".app") {
            return path
        }
        return URL(fileURLWithPath: path).appendingPathComponent("Hearthstone.app").path
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
                self?.setBusy(false, title: finished.terminationStatus == 0 ? "Ready" : "Failed")
                let ok = finished.terminationStatus == 0
                self?.appendLog("\nProcess exited with status \(finished.terminationStatus).\n")
                if !ok {
                    self?.showAlert("Install failed. Check the log in this window.")
                }
                completion(ok)
            }
        }

        do {
            try process.run()
        } catch {
            currentProcess = nil
            setBusy(false, title: "Failed")
            showAlert(error.localizedDescription)
        }
    }

    private func setBusy(_ busy: Bool, title: String) {
        installButton.isEnabled = !busy
        reinjectButton.isEnabled = !busy
        statusLabel.stringValue = title
        busy ? progress.startAnimation(nil) : progress.stopAnimation(nil)
    }

    private func appendLog(_ text: String) {
        let end = NSRange(location: logView.string.count, length: 0)
        logView.textStorage?.replaceCharacters(in: end, with: text)
        logView.scrollToEndOfDocument(nil)
    }

    private func openBattleNet() {
        let url = URL(fileURLWithPath: "/Applications/Battle.net.app")
        NSWorkspace.shared.open(url)
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "HsMod macOS Installer"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = InstallerController()
app.delegate = delegate
app.run()
