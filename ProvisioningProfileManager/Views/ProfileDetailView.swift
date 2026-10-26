import SwiftUI

struct ProfileDetailView: View {
    @Environment(ProfileStore.self) private var store
    let profile: ProvisioningProfile

    @State private var showsRawPlist = false

    var body: some View {
        let now = Date()
        let health = profile.health(now: now, warningDays: store.warningDays)

        Form {
            Section {
                header(health: health)
            }

            if let error = profile.parseError {
                Section("Error") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } else {
                generalSection
                datesSection(now: now)
                certificatesSection(now: now)
                CapabilitiesSection(entitlements: profile.entitlements)
                devicesSection
            }
            fileSection
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showsRawPlist) {
            RawPlistView(title: profile.name, text: profile.rawPlist)
        }
    }

    // MARK: Sections

    private func header(health: ProfileHealth) -> some View {
        HStack(alignment: .center, spacing: 14) {
            TypeIcon(type: profile.type, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .scaledFont(.title2, weight: .semibold)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    TypeBadge(type: profile.type)
                    ExpirationBadges(profile: profile)
                }
                if case .invalid(let reason) = health {
                    Label(reason, systemImage: "exclamationmark.octagon.fill")
                        .scaledFont(.callout)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var generalSection: some View {
        Section("General") {
            row("Name", profile.name)
            row("UUID", profile.uuid, monospaced: true)
            row("App ID Name", profile.appIDName)
            row("Bundle ID", profile.bundleID, monospaced: true)
            row("Application Identifier", profile.applicationIdentifier, monospaced: true)
            LabeledContent("Type") { TypeBadge(type: profile.type) }
            row("Platforms", profile.platforms.joined(separator: ", "))
            row("Team", profile.teamName)
            row("Team ID", profile.teamIdentifiers.joined(separator: ", "), monospaced: true)
            row("Xcode Managed", profile.isXcodeManaged ? "Yes" : "No")
            if let version = profile.version { row("Version", String(version)) }
            if let ttl = profile.timeToLive { row("Time to Live", "\(ttl) days") }
        }
    }

    private func datesSection(now: Date) -> some View {
        let status = profile.profileStatus(now: now, warningDays: store.warningDays)
        return Section("Dates") {
            row("Created", profile.creationDate?.formatted(date: .long, time: .shortened) ?? "—")
            LabeledContent("Expires") {
                HStack(spacing: 6) {
                    Text(profile.expirationDate?.formatted(date: .long, time: .shortened) ?? "—")
                    Circle().fill(status.color).frame(width: 8, height: 8)
                }
            }
            if let date = profile.expirationDate {
                LabeledContent("Remaining") {
                    Text(status == .expired
                         ? "Expired \(date.formatted(.relative(presentation: .named)))"
                         : "\(ExpirationStatus.daysRemaining(until: date, now: now)) days")
                        .foregroundStyle(status == .valid ? Color.secondary : status.color)
                }
            }
        }
    }

    @ViewBuilder
    private func certificatesSection(now: Date) -> some View {
        let summary = profile.certificateSummary(now: now, warningDays: store.warningDays)

        Section {
            if summary.status != .valid {
                CertificateStatusBanner(summary: summary)
            }
            ForEach(profile.installedCertificates) { certificate in
                CertificateRow(certificate: certificate, status: certificate.status(now: now, warningDays: store.warningDays))
            }
            if summary.installed == 0 {
                Text("None of the certificates in this profile is installed.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Installed Certificates in This Profile (\(summary.installed))")
        } footer: {
            footnote("Only certificates installed in your keychain with their private key are shown and checked for expiration. The profile includes \(summary.total) certificate\(summary.total == 1 ? "" : "s") in total, usually belonging to other team members.")
        }

        if !profile.keychainCertificatesNotInProfile.isEmpty {
            Section {
                ForEach(profile.keychainCertificatesNotInProfile) { certificate in
                    CertificateRow(certificate: certificate, status: certificate.status(now: now, warningDays: store.warningDays))
                }
            } header: {
                Text("Your Installed Certificates Not in This Profile (\(profile.keychainCertificatesNotInProfile.count))")
            } footer: {
                footnote("Valid certificates installed in your keychain for the same developer, but not included in the profile: this profile can't be used to sign with them.")
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .scaledFont(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var devicesSection: some View {
        Section("Devices") {
            if profile.provisionsAllDevices {
                Label("All devices", systemImage: "infinity")
            } else if profile.provisionedDevices.isEmpty {
                Text("No devices (distribution profile)")
                    .foregroundStyle(.secondary)
            } else {
                DisclosureGroup("\(profile.provisionedDevices.count) provisioned devices") {
                    ForEach(profile.provisionedDevices, id: \.self) { udid in
                        Text(udid)
                            .scaledFont(.caption, design: .monospaced)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var fileSection: some View {
        Section("File") {
            ForEach(profile.fileURLs, id: \.self) { url in
                LabeledContent("Path") {
                    Text(url.path)
                        .scaledFont(.caption)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .truncationMode(.middle)
                }
            }
            row("Size", ByteCountFormatter.string(fromByteCount: profile.fileSize, countStyle: .file))
            HStack {
                Button("Show in Finder") { store.revealInFinder([profile.id]) }
                Button("Show Raw Plist") { showsRawPlist = true }
                    .disabled(profile.rawPlist.isEmpty)
                Spacer()
                Button("Move to Trash…", role: .destructive) { store.requestDelete(ids: [profile.id]) }
            }
        }
    }

    private func row(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        LabeledContent(title) {
            Text(value.isEmpty ? "—" : value)
                .scaledFont(.body, design: monospaced ? .monospaced : .default)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CertificateRow: View {
    let certificate: CertificateInfo
    let status: ExpirationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: status == .expired ? "xmark.seal.fill" : "checkmark.seal.fill")
                    .foregroundStyle(status.color)
                Text(certificate.commonName)
                    .scaledFont(.headline)
                    .textSelection(.enabled)
                Spacer()
                Text(status == .expired ? "Expired" : status == .expiringSoon ? "Expiring soon" : "Valid")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(status.color)
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                gridRow("Valid from", certificate.notBefore?.formatted(date: .long, time: .shortened) ?? "—")
                GridRow {
                    Text("Valid until").foregroundStyle(.secondary)
                    Text(certificate.notAfter?.formatted(date: .long, time: .shortened) ?? "—")
                        .foregroundStyle(status == .valid ? Color.primary : status.color)
                }
                gridRow("Serial", certificate.serialNumber, monospaced: true)
                gridRow("SHA-1", certificate.sha1, monospaced: true)
            }
            .scaledFont(.caption)
        }
        .padding(.vertical, 2)
    }

    private func gridRow(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value)
                .scaledFont(.caption, design: monospaced ? .monospaced : .default)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct CertificateStatusBanner: View {
    let summary: CertificateSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: summary.status.symbol)
                .scaledFont(.title2)
                .foregroundStyle(summary.status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(.headline)
                    .foregroundStyle(summary.status.color)
                Text(StatusText.certificateExplanation(summary))
                    .scaledFont(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(summary.status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch summary.status {
        case .missing:
            summary.validCertificatesNotInProfile.isEmpty
                ? "Certificate not installed"
                : "Your installed certificate is not in this profile"
        case .expired: "Installed certificate expired"
        case .expiringSoon: "Installed certificate expiring soon"
        case .valid: "Valid certificate installed"
        }
    }
}

private struct RawPlistView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).scaledFont(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()
            ScrollView([.vertical, .horizontal]) {
                Text(text)
                    .scaledFont(.caption, design: .monospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 700, minHeight: 560)
    }
}
