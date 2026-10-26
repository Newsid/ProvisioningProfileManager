import Foundation
import Testing
@testable import ProvisioningProfileManager

@MainActor
struct ProfileStoreZoomTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "ZoomTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func stepsThroughZoomLevelsWithinBounds() {
        let store = ProfileStore(defaults: makeDefaults(), autoload: false)
        #expect(store.fontScale == 1)

        store.zoomIn()
        #expect(store.fontScale == 1.1)
        store.zoomOut()
        store.zoomOut()
        #expect(store.fontScale == 0.9)

        for _ in 0..<20 { store.zoomOut() }
        #expect(store.fontScale == ProfileStore.fontScaleSteps.first)
        #expect(!store.canZoomOut)

        for _ in 0..<20 { store.zoomIn() }
        #expect(store.fontScale == ProfileStore.fontScaleSteps.last)
        #expect(!store.canZoomIn)

        store.resetZoom()
        #expect(store.fontScale == 1)
    }

    @Test func remembersZoomAndSnapsSavedValuesToAStep() {
        let defaults = makeDefaults()
        ProfileStore(defaults: defaults, autoload: false).zoomIn()
        #expect(ProfileStore(defaults: defaults, autoload: false).fontScale == 1.1)

        defaults.set(1.3, forKey: "fontScale")
        #expect(ProfileStore(defaults: defaults, autoload: false).fontScale == 1.25)
    }
}
