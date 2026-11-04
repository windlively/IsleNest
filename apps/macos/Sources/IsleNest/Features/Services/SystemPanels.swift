import AppKit
import IsleNestCore
import UniformTypeIdentifiers

@MainActor
enum SystemPanels {
    static func chooseDirectories(limit: Int, message: String) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = limit > 1
        panel.canCreateDirectories = true
        panel.prompt = "固定"
        panel.message = message
        guard panel.runModal() == .OK else {
            return []
        }
        return Array(panel.urls.prefix(max(1, limit)))
    }

    static func chooseDirectory(message: String, prompt: String = "选择") -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = prompt
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseStagingFiles(limit: Int) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = limit > 1
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "暂存"
        panel.message = "选择要暂存的文件或文件夹；原文件不会被移动"
        guard panel.runModal() == .OK else {
            return []
        }
        return Array(panel.urls.prefix(max(1, limit)))
    }

    static func chooseApplications(limit: Int) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = limit > 1
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "添加"
        panel.message = "选择要固定的应用"
        guard panel.runModal() == .OK else {
            return []
        }
        return Array(panel.urls.prefix(max(1, limit)))
    }

    static func rename(title: String, message: String, current: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = current
        field.placeholderString = "名称"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func website(
        title: String,
        message: String,
        initialTitle: String,
        initialURL: String
    ) -> (title: String, urlString: String)? {
        var draftTitle = initialTitle
        var draftURL = initialURL

        while true {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "取消")

            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 60))
            let titleField = NSTextField(frame: NSRect(x: 0, y: 34, width: 340, height: 24))
            titleField.placeholderString = "标题（可选）"
            titleField.stringValue = draftTitle

            let urlField = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
            urlField.placeholderString = "https://example.com"
            urlField.stringValue = draftURL

            accessory.addSubview(titleField)
            accessory.addSubview(urlField)
            alert.accessoryView = accessory
            alert.window.initialFirstResponder = titleField

            guard alert.runModal() == .alertFirstButtonReturn else {
                return nil
            }

            draftTitle = titleField.stringValue
            draftURL = urlField.stringValue

            if WebsiteURL.normalize(draftURL) != nil {
                return (draftTitle, draftURL)
            }

            let invalid = NSAlert()
            invalid.messageText = "网址无效"
            invalid.informativeText = "只支持 http 或 https 网址，请重新输入。"
            invalid.alertStyle = .warning
            invalid.addButton(withTitle: "重新输入")
            invalid.addButton(withTitle: "取消")
            guard invalid.runModal() == .alertFirstButtonReturn else {
                return nil
            }
        }
    }

    static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    static func confirmDestructive(
        title: String,
        message: String,
        confirmTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
