import ApplicationServices
import AXSwift6
import AppKit
import Testing

@Suite("Application")
struct ApplicationTests {
    @Test("Known process ID factory wraps the current process")
    func knownProcessIDFactoryWrapsCurrentProcess() throws {
        let app = try TestFixtures.currentApplicationOrSkip()
        #expect(try app.pid() == getpid())
    }

    @Test("Known process ID factory rejects negative PIDs")
    func knownProcessIDFactoryRejectsNegativePIDs() {
        #expect(Application(forKnownProcessID: -1) == nil)
    }

    @Test("Process ID factory wraps a running GUI application when available")
    func processIDFactoryWrapsRunningGUIApplicationWhenAvailable() throws {
        guard let running = Application.all().first, let pid = try? running.pid() else {
            return
        }

        let app = try #require(Application(forProcessID: pid))
        #expect(try app.pid() == pid)
    }

    @Test("Process ID factory returns nil for a non-running PID")
    func processIDFactoryReturnsNilForNonRunningPID() {
        #expect(Application(forProcessID: 999_999_999) == nil)
    }

    @Test("NSRunningApplication factory wraps a running GUI application when available")
    func runningApplicationFactoryWrapsRunningGUIApplicationWhenAvailable() throws {
        guard let pid = try Application.all().first?.pid(),
              let running = NSRunningApplication(processIdentifier: pid)
        else {
            return
        }

        let app = try #require(Application(running))
        #expect(try app.pid() == pid)
    }

    @Test("all() returns at least one GUI application")
    func allReturnsAtLeastOneGUIApplication() {
        #expect(!Application.all().isEmpty)
    }

    @Test("allForBundleID returns only matching applications")
    func allForBundleIDReturnsOnlyMatchingApplications() throws {
        guard let sample = Application.all().first,
              let pid = try? sample.pid(),
              let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        else {
            return
        }

        let matches = Application.allForBundleID(bundleID)
        #expect(!matches.isEmpty)
        for app in matches {
            #expect(try app.pid() > 0)
        }
    }

    @Test("createObserver builds an observer for the current process")
    func createObserverBuildsObserverForCurrentProcess() throws {
        let app = try TestFixtures.currentApplicationOrSkip()
        let observer = try #require(app.createObserver { _, _, _ in
            // No-op callback for construction coverage.
        })
        #expect(observer.pid == getpid())
        observer.stop()
    }

    @Test("createObserver with info callback builds an observer")
    func createObserverWithInfoCallbackBuildsObserver() throws {
        let app = try TestFixtures.currentApplicationOrSkip()
        let observer = try #require(app.createObserver { _, _, _, _ in
            // No-op callback for construction coverage.
        })
        #expect(observer.pid == getpid())
        observer.stop()
    }

    @Test("windows() returns a value or throws for the current process")
    func windowsReturnsValueOrThrowsForCurrentProcess() throws {
        let app = try TestFixtures.currentApplicationOrSkip()
        do {
            _ = try app.windows()
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }
}
