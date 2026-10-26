import AppKit
import SwiftUI

/// Native search field for the leading edge of the toolbar (`.searchable` always places its
/// field at the trailing edge). The scope (name / bundle ID) is picked from the magnifier menu,
/// and ⌘F focuses the field.
struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var scope: SearchScope

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        context.coordinator.installFindShortcut(for: field)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = scope == .name ? "Filter by name" : "Filter by bundle ID"
        field.searchMenuTemplate = context.coordinator.scopeMenu(selected: scope)
    }

    static func dismantleNSView(_ field: NSSearchField, coordinator: Coordinator) {
        coordinator.removeFindShortcut()
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: ToolbarSearchField
        private var findMonitor: Any?

        init(parent: ToolbarSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func scopeMenu(selected: SearchScope) -> NSMenu {
            let menu = NSMenu()
            let header = NSMenuItem(title: "Search In", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for scope in SearchScope.allCases {
                let item = NSMenuItem(title: scope.title, action: #selector(selectScope(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = scope.rawValue
                item.state = scope == selected ? .on : .off
                menu.addItem(item)
            }
            return menu
        }

        @objc private func selectScope(_ sender: NSMenuItem) {
            guard let raw = sender.representedObject as? String, let scope = SearchScope(rawValue: raw) else { return }
            parent.scope = scope
        }

        func installFindShortcut(for field: NSSearchField) {
            findMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak field] event in
                guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                      event.charactersIgnoringModifiers == "f"
                else { return event }
                let eventWindow = event.window
                // Local monitors run on the main thread.
                let focused = MainActor.assumeIsolated {
                    guard let field, let window = field.window, eventWindow === window else { return false }
                    window.makeFirstResponder(field)
                    return true
                }
                return focused ? nil : event
            }
        }

        func removeFindShortcut() {
            if let findMonitor { NSEvent.removeMonitor(findMonitor) }
            findMonitor = nil
        }
    }
}
