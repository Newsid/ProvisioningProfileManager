import SwiftUI

private struct DeleteConfirmationModifier: ViewModifier {
    @Environment(ProfileStore.self) private var store

    private let maxListed = 10

    func body(content: Content) -> some View {
        @Bindable var store = store
        let pending = store.pendingDeletion

        content
            .confirmationDialog(
                pending.count == 1
                    ? "Move “\(pending[0].name)” to the Trash?"
                    : "Move \(pending.count) provisioning profiles to the Trash?",
                isPresented: $store.isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button(pending.count == 1 ? "Move to Trash" : "Move \(pending.count) to Trash", role: .destructive) {
                    store.confirmDelete()
                }
                Button("Cancel", role: .cancel) { store.cancelDelete() }
            } message: {
                Text(message(for: pending))
            }
            .alert(
                "Some profiles could not be deleted",
                isPresented: Binding(
                    get: { !store.deletionErrors.isEmpty },
                    set: { if !$0 { store.deletionErrors = [] } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.deletionErrors.joined(separator: "\n"))
            }
    }

    private func message(for profiles: [ProvisioningProfile]) -> String {
        var lines = profiles.prefix(maxListed).map { "• \($0.name)" }
        if profiles.count > maxListed {
            lines.append("…and \(profiles.count - maxListed) more")
        }
        lines.append("")
        lines.append("You can restore them from the Trash.")
        return lines.joined(separator: "\n")
    }
}

extension View {
    func deleteConfirmation() -> some View {
        modifier(DeleteConfirmationModifier())
    }
}
