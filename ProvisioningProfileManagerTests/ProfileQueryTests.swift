import Foundation
import Testing
@testable import ProvisioningProfileManager

struct ExpirationTests {
    @Test func evaluatesStatus() {
        #expect(ExpirationStatus.evaluate(days(-1), now: referenceNow, warningDays: 30) == .expired)
        #expect(ExpirationStatus.evaluate(days(10), now: referenceNow, warningDays: 30) == .expiringSoon)
        #expect(ExpirationStatus.evaluate(days(31), now: referenceNow, warningDays: 30) == .valid)
        #expect(ExpirationStatus.evaluate(nil, now: referenceNow, warningDays: 30) == .valid)
    }

    private func health(_ profile: ProvisioningProfile) -> ProfileHealth {
        profile.health(now: referenceNow, warningDays: 30)
    }

    private func summary(_ profile: ProvisioningProfile) -> CertificateSummary {
        profile.certificateSummary(now: referenceNow, warningDays: 30)
    }

    @Test func profileExpiration() {
        #expect(health(makeProfile(name: "ok")) == .ok)
        #expect(health(makeProfile(name: "a", expires: days(5))) == .expiringSoon)
        #expect(health(makeProfile(name: "b", expires: days(-5))) == .invalid(reason: "Profile expired"))
    }

    @Test func onlyInstalledCertificatesCount() {
        // A colleague's expired certificate doesn't matter when mine is valid…
        let team = makeProfile(name: "team", certificates: [
            makeCertificate(name: "Colleague", expires: days(-3), installed: false),
            makeCertificate(name: "Me", expires: days(300)),
        ])
        #expect(health(team) == .ok)
        #expect(summary(team).total == 2 && summary(team).installed == 1)
        #expect(team.installedCertificates.map(\.commonName) == ["Me"])

        // …and a colleague's valid certificate doesn't help when mine has expired.
        let mineExpired = makeProfile(name: "team", certificates: [
            makeCertificate(name: "Colleague", expires: days(300), installed: false),
            makeCertificate(name: "Me", expires: days(-3)),
        ])
        #expect(summary(mineExpired).status == .expired)
        #expect(health(mineExpired) == .invalid(reason: "Installed certificate expired"))
    }

    @Test func bestInstalledCertificateWins() {
        let renewed = makeProfile(name: "renewed", certificates: [
            makeCertificate(name: "Old", expires: days(-3)),
            makeCertificate(name: "New", expires: days(300)),
        ])
        #expect(summary(renewed).status == .valid)

        let expiring = makeProfile(name: "expiring", certificates: [makeCertificate(expires: days(3))])
        #expect(summary(expiring).status == .expiringSoon)
        #expect(health(expiring) == .expiringSoon)
        #expect(StatusText.certificates(summary(expiring), now: referenceNow) == "Certificate expires in 3 days")
    }

    @Test func distinguishesMissingFromExpiredCertificates() {
        let missing = makeProfile(name: "missing", certificates: [
            makeCertificate(expires: days(300), installed: false),
        ])
        let expired = makeProfile(name: "expired", certificates: [makeCertificate(expires: days(-1))])
        let empty = makeProfile(name: "empty", certificates: [])

        #expect(summary(missing).status == .missing)
        #expect(health(missing) == .invalid(reason: "No installed certificate"))
        #expect(StatusText.certificates(summary(missing), now: referenceNow) == "Certificate not installed")

        #expect(summary(expired).status == .expired)
        #expect(health(expired) == .invalid(reason: "Installed certificate expired"))
        #expect(StatusText.certificates(summary(expired), now: referenceNow) == "Certificate expired")

        #expect(summary(empty).status == .missing)
    }

    @Test func findsYourCertificatesTheProfileDoesNotMatch() {
        let oldMine = makeCertificate(name: "Apple Development: Me (TEAM)", expires: days(-30), installed: false)
        let colleague = makeCertificate(name: "Apple Development: Colleague (TEAM)", expires: days(3), installed: false)
        var profile = makeProfile(name: "stale", certificates: [oldMine, colleague])

        let newMine = makeCertificate(name: "Apple Development: Me (TEAM)", expires: days(300))
        let expiredMine = makeCertificate(name: "Apple Development: Me (TEAM)", expires: days(-10))
        let otherTeam = makeCertificate(name: "Apple Development: Me (OTHER)", expires: days(300))
        profile.linkKeychain(identities: [newMine, expiredMine, otherTeam], now: referenceNow)

        #expect(profile.installedCertificates.isEmpty)
        // Only valid installed certificates of the same developer are reported.
        #expect(profile.keychainCertificatesNotInProfile.map(\.sha1) == [newMine.sha1])

        let summary = summary(profile)
        #expect(summary.status == .missing)
        #expect(summary.validCertificatesNotInProfile == ["Apple Development: Me (TEAM)"])
        #expect(StatusText.certificates(summary, now: referenceNow) == "Installed certificate not in profile")
        #expect(health(profile) == .invalid(reason: "Your installed certificate is not in this profile"))
        // The colleague's certificate expiring in 3 days is irrelevant.
        #expect(StatusText.certificates(summary, now: referenceNow)?.contains("3 days") == false)
    }

    @Test func linkKeychainMarksInstalledCertificates() {
        let mine = makeCertificate(name: "Apple Development: Me (TEAM)", expires: days(300), installed: false)
        var profile = makeProfile(name: "current", certificates: [mine])
        profile.linkKeychain(identities: [makeCertificate(name: mine.commonName, expires: days(300)).withSHA1(mine.sha1)], now: referenceNow)

        #expect(profile.installedCertificates.count == 1)
        #expect(profile.keychainCertificatesNotInProfile.isEmpty)
        #expect(summary(profile).status == .valid)
    }

    @Test func warnsOnlyAboutInstalledCertificates() {
        let colleagues = [
            makeCertificate(name: "Colleague A", expires: days(-100), installed: false),
            makeCertificate(name: "Colleague B", expires: days(2), installed: false),
        ]
        // Valid installed certificate: no warning, whatever the others do.
        let valid = makeProfile(name: "valid", certificates: colleagues + [makeCertificate(name: "Me", expires: days(300))])
        #expect(StatusText.certificates(summary(valid), now: referenceNow) == nil)
        #expect(health(valid) == .ok)

        // The warning reflects my certificate only.
        let expiring = makeProfile(name: "expiring", certificates: colleagues + [makeCertificate(name: "Me", expires: days(10))])
        #expect(StatusText.certificates(summary(expiring), now: referenceNow) == "Certificate expires in 10 days")

        // None installed: "not installed", never a colleague's expiration.
        let none = makeProfile(name: "none", certificates: colleagues)
        #expect(StatusText.certificates(summary(none), now: referenceNow) == "Certificate not installed")
    }

    @Test func profileExpirationTakesPrecedence() {
        let both = makeProfile(name: "both", expires: days(-1), certificates: [
            makeCertificate(expires: days(300), installed: false),
        ])
        #expect(health(both) == .invalid(reason: "Profile expired"))
    }
}

struct ProfileQueryTests {
    private let profiles = [
        makeProfile(name: "Beta", bundleID: "com.b.app", type: .adHoc, expires: days(100)),
        makeProfile(name: "alpha", bundleID: "com.c.app", type: .development, expires: days(10)),
        makeProfile(name: "Gamma", bundleID: "com.a.app", type: .appStore, expires: days(-1)),
        makeProfile(name: "Delta", bundleID: "com.b.app", type: .development, expires: nil),
    ]

    private func query(_ configure: (inout ProfileQuery) -> Void = { _ in }) -> ProfileQuery {
        var query = ProfileQuery(now: referenceNow)
        configure(&query)
        return query
    }

    @Test func sortsByNameCaseInsensitively() {
        let names = query().apply(to: profiles).map(\.name)
        #expect(names == ["alpha", "Beta", "Delta", "Gamma"])
        let descending = query { $0.ascending = false }.apply(to: profiles).map(\.name)
        #expect(descending == ["Gamma", "Delta", "Beta", "alpha"])
    }

    @Test func sortsByBundleIDThenName() {
        let names = query { $0.sortField = .bundleID }.apply(to: profiles).map(\.name)
        #expect(names == ["Gamma", "Beta", "Delta", "alpha"])
    }

    @Test func sortsByExpirationWithMissingDatesLast() {
        let ascending = query { $0.sortField = .expirationDate }.apply(to: profiles).map(\.name)
        #expect(ascending == ["Gamma", "alpha", "Beta", "Delta"])
        let descending = query { $0.sortField = .expirationDate; $0.ascending = false }.apply(to: profiles).map(\.name)
        #expect(descending == ["Beta", "alpha", "Gamma", "Delta"])
    }

    @Test func filtersByNameOrBundleID() {
        #expect(query { $0.searchText = "ALP" }.apply(to: profiles).map(\.name) == ["alpha"])
        #expect(query { $0.searchText = "com.b"; $0.searchScope = .bundleID }.apply(to: profiles).map(\.name) == ["Beta", "Delta"])
        #expect(query { $0.searchText = "com.b"; $0.searchScope = .name }.apply(to: profiles).isEmpty)
    }

    @Test func filtersBySidebarSection() {
        #expect(query { $0.sidebar = .expiredOrInvalid }.apply(to: profiles).map(\.name) == ["Gamma"])
        #expect(query { $0.sidebar = .expiringSoon }.apply(to: profiles).map(\.name) == ["alpha"])
        #expect(query { $0.sidebar = .type(.development) }.apply(to: profiles).map(\.name) == ["alpha", "Delta"])
        #expect(query().count(for: .type(.adHoc), in: profiles) == 1)
    }

    @Test func groupsByBundleID() {
        let query = query()
        let groups = query.grouped(query.apply(to: profiles))
        #expect(groups.map(\.id) == ["com.a.app", "com.b.app", "com.c.app"])
        #expect(groups[1].profiles.map(\.name) == ["Beta", "Delta"])

        let descending = self.query { $0.sortField = .bundleID; $0.ascending = false }
        #expect(descending.grouped(descending.apply(to: profiles)).map(\.id) == ["com.c.app", "com.b.app", "com.a.app"])
    }
}
