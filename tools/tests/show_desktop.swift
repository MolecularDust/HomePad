import AppKit
import ApplicationServices

// Only the OS boundary is simulated. Compile this with the unchanged production ShowDesktop.swift.
// Each successful setter waits at a gate: all requests must arrive before any can finish. Serial minimize OR restore
// implementations fail this test, including implementations that serialize windows belonging to the same app.
enum Permissions {
    static var accessibility = true
    static var screenRecording = true
    static func requestScreenRecording() { requested = true }
    static var requested = false
    static func requestAccessibility() { requested = true }
}
let stateLock = NSLock()
func locked<T>(_ action: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return action()
}
enum SkyLight {
    private static var space: Int? = 1
    static var activeSpace: Int? {
        get { locked { space } }
        set { locked { space = newValue } }
    }
    static var visibleSpacesOverride: [Int]?
    static var visibleSpaces: [Int] { visibleSpacesOverride ?? activeSpace.map { [$0] } ?? [] }
    static var focused: [CGWindowID] = []
    static func focus(window: CGWindowID, pid: pid_t) { locked { focused.append(window) } }
    static func raisePreservingOthers(window: CGWindowID, pid: pid_t) { locked { focused.append(window) } }
    static func activatePreservingWindowOrder(pid: pid_t) {}
}
final class PanelController {
    static let shared = PanelController()
    func hide(restoreFocus: Bool) {}
}
final class TaskbarFlyout {
    static let shared = TaskbarFlyout()
    func close() {}
}
final class WindowPreviewController {
    static let shared = WindowPreviewController()
    func hideNow() {}
}
@MainActor final class DesktopTransition {
    struct Scene: Equatable { let identity = UUID() }
    func begin(excludingWindowIDs: Set<CGWindowID>, restoring scene: Scene?) async throws -> Scene? {
        if failCapture { throw NSError(domain: "capture-test", code: 1) }
        coverExcludedIDs = excludingWindowIDs
        restoredScene = scene
        locked { covered = true }
        capturedScene = excludingWindowIDs.isEmpty ? nil : Scene()
        return capturedScene
    }
    func finish() {
        require(locked { pendingAnimations == 0 }, "must not reveal unfinished animations")
        locked { covered = false }
    }
    func finishAfterRendering() async { finish() }
}
var covered = false
var coverExcludedIDs: Set<CGWindowID> = []
var restoredScene: DesktopTransition.Scene?
var capturedScene: DesktopTransition.Scene?
var failCapture = false
var pendingAnimations = 0
var hiddenApps: Set<pid_t> = []
var unhideDelay = 0.0
var failedUnhides: Set<pid_t> = []
var scheduledUnhides: Set<pid_t> = []
func requestUnhide(_ pid: pid_t) {
    // Caller holds stateLock. Both native and AX acknowledgements can precede the real unhide.
    guard !failedUnhides.contains(pid) else { return }
    if unhideDelay == 0 { hiddenApps.remove(pid); return }
    guard scheduledUnhides.insert(pid).inserted else { return }
    DispatchQueue.global().asyncAfter(deadline: .now() + unhideDelay) {
        locked { hiddenApps.remove(pid); scheduledUnhides.remove(pid) }
    }
}
// Keep the native hide/unhide boundary simulated too: fake fixture PIDs must never address real system processes.
final class NSRunningApplication {
    let processIdentifier: pid_t
    init?(processIdentifier: pid_t) {
        guard fixtures.contains(where: { $0.pid == processIdentifier }) else { return nil }
        self.processIdentifier = processIdentifier
    }
    func hide() -> Bool { locked { hiddenApps.insert(processIdentifier); return true } }
    func unhide() -> Bool { locked { requestUnhide(processIdentifier); return true } }
    var isHidden: Bool { locked { hiddenApps.contains(processIdentifier) } }
}
struct Fixture {
    let id: CGWindowID
    let pid: pid_t
    var element: AXUIElement
    var acknowledgesChange = true
    var replacesElementOnChange = false
    var generation = 0
    var minimized = false
    var reportedID: CGWindowID?
    var renumbersOnChange = false
    var fullScreen = false
    var settable = true
    var succeeds = true
    var closed = false
    var placement: CGRect?
}
var fixtures: [Fixture] = []
var visible: [[String: Any]] = []
var changed: [(CGWindowID, Bool)] = []
var raised: [CGWindowID] = []
var stacking: [CGWindowID] = []
var waiting = 0
var gate = DispatchSemaphore(value: 0)
func fixtureIndex(_ element: AXUIElement) -> Int? {
    fixtures.firstIndex { CFEqual($0.element, element) }
}
enum RemoteAX {
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        locked { fixtureIndex(element).map { fixtures[$0].reportedID ?? fixtures[$0].id } }
    }
}
@discardableResult
func AXUIElementSetMessagingTimeout(_ element: AXUIElement, _ timeout: Float) -> AXError { .success }
@discardableResult
func AXUIElementCopyAttributeValue(_ element: AXUIElement, _ attribute: CFString, _ value: UnsafeMutablePointer<CFTypeRef?>) -> AXError {
    locked {
        let name = attribute as String
        if name == kAXHiddenAttribute {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            value.pointee = hiddenApps.contains(pid) ? kCFBooleanTrue : kCFBooleanFalse
            return .success
        }
        if name == kAXWindowsAttribute {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            value.pointee = fixtures.filter { $0.pid == pid && !$0.closed }.map(\.element) as CFArray
            return .success
        }
        guard let index = fixtureIndex(element), !fixtures[index].closed else { return .invalidUIElement }
        if name == kAXMinimizedAttribute {
            guard fixtures[index].settable else { return .attributeUnsupported }
            value.pointee = fixtures[index].minimized ? kCFBooleanTrue : kCFBooleanFalse
        }
        else if name == "AXFullScreen" { value.pointee = fixtures[index].fullScreen ? kCFBooleanTrue : kCFBooleanFalse }
        else if name == kAXPositionAttribute {
            var point = fixtures[index].placement?.origin ?? CGPoint(x: Int(fixtures[index].id) * 30, y: 100)
            if fixtures[index].minimized && fixtures[index].renumbersOnChange { point.x = -10000 }
            value.pointee = AXValueCreate(.cgPoint, &point)
        } else if name == kAXSizeAttribute {
            var size = fixtures[index].placement?.size ?? CGSize(width: 600, height: 400)
            value.pointee = AXValueCreate(.cgSize, &size)
        } else if name == kAXTitleAttribute { value.pointee = "Fixture \(fixtures[index].id)" as CFString }
        else { return .attributeUnsupported }
        return .success
    }
}
func AXUIElementIsAttributeSettable(_ element: AXUIElement, _ attribute: CFString, _ settable: UnsafeMutablePointer<DarwinBoolean>) -> AXError {
    locked {
        guard let index = fixtureIndex(element) else { return .invalidUIElement }
        settable.pointee = DarwinBoolean(fixtures[index].settable)
        return .success
    }
}
@discardableResult
func AXUIElementPerformAction(_ element: AXUIElement, _ action: CFString) -> AXError {
    locked {
        if let index = fixtureIndex(element), action as String == kAXRaiseAction {
            let id = fixtures[index].id
            raised.append(id)
            stacking.removeAll { $0 == id }
            stacking.insert(id, at: 0)
        }
        return .success
    }
}
func AXUIElementSetAttributeValue(_ element: AXUIElement, _ attribute: CFString, _ value: CFTypeRef) -> AXError {
    if attribute as String == kAXPositionAttribute || attribute as String == kAXSizeAttribute {
        return locked {
            require(covered, "layout must settle before the cover is removed")
            guard let index = fixtureIndex(element) else { return .invalidUIElement }
            var rect = fixtures[index].placement ?? CGRect(x: Int(fixtures[index].id) * 30, y: 100, width: 600, height: 400)
            let axValue = value as! AXValue
            if attribute as String == kAXPositionAttribute { AXValueGetValue(axValue, .cgPoint, &rect.origin) }
            else { AXValueGetValue(axValue, .cgSize, &rect.size) }
            fixtures[index].placement = rect
            return .success
        }
    }
    if attribute as String == kAXHiddenAttribute {
        return locked {
            require(covered, "app visibility changes must be covered")
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            if CFEqual(value, kCFBooleanTrue) { hiddenApps.insert(pid) } else { requestUnhide(pid) }
            return .success
        }
    }
    let minimized = CFEqual(value, kCFBooleanTrue)
    let immediate: AXError? = locked {
        require(covered, "window changes must be covered")
        guard let index = fixtureIndex(element), !fixtures[index].closed, fixtures[index].succeeds else { return .failure }
        // Some real apps accept but ignore window changes while hidden. The normal path must not hide them.
        if hiddenApps.contains(fixtures[index].pid) { return .success }
        // Like real AppKit, restoring an already restored window is a harmless no-op.
        if fixtures[index].minimized == minimized { return .success }
        waiting += 1
        return nil
    }
    if let immediate { return immediate }
    gate.wait()
    let index = locked { fixtureIndex(element)! }
    locked { pendingAnimations += 1 }
    // Real AX setters acknowledge before animation completion. Complete these on different frames to reproduce
    // the Dock's serial queue and ensure the cover survives until the last state is confirmed.
    DispatchQueue.global().asyncAfter(deadline: .now() + Double(index + 1) * 0.015) {
        locked {
            require(covered, "queued animation became visible before it finished")
            fixtures[index].minimized = minimized
            if !minimized, fixtures[index].id == 11 {
                fixtures[index].placement = CGRect(x: 500, y: 300, width: 700, height: 450)
            }
            changed.append((fixtures[index].id, minimized))
            if fixtures[index].renumbersOnChange {
                fixtures[index].generation += 1
                fixtures[index].reportedID = 100000 + fixtures[index].id + UInt32(fixtures[index].generation * 1000)
            }
            if fixtures[index].replacesElementOnChange {
                fixtures[index].generation += 1
                fixtures[index].element = ApplicationServices.AXUIElementCreateApplication(pid_t(30000 + Int(fixtures[index].id) + fixtures[index].generation * 1000))
            }
            pendingAnimations -= 1
        }
    }
    return locked { fixtures[index].acknowledgesChange ? .success : .cannotComplete }
}
func CGWindowListCopyWindowInfo(_ options: CGWindowListOption, _ window: CGWindowID) -> CFArray? {
    locked {
        func row(_ fixture: Fixture) -> [String: Any] {
            [kCGWindowOwnerPID as String: fixture.pid,
             kCGWindowNumber as String: fixture.reportedID ?? fixture.id,
             kCGWindowBounds as String: (fixture.placement ?? CGRect(x: Int(fixture.id) * 30, y: 100, width: 600, height: 400)).dictionaryRepresentation,
             kCGWindowLayer as String: 0, kCGWindowAlpha as String: 1.0]
        }
        let local = visible.filter { $0[kCGWindowOwnerPID as String] as? pid_t == getpid() }
        if options == .optionAll {
            // Reproduce renderers that drop the drawable surface while a window is minimized.
            return (fixtures.filter { !$0.closed && !$0.minimized }.map(row) + local) as CFArray
        }
        let onScreen = visible.compactMap { info -> [String: Any]? in
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let fixture = fixtures.first(where: { $0.id == id }) else { return nil }
            guard !fixture.closed && !fixture.minimized && !hiddenApps.contains(fixture.pid) else { return nil }
            var result = row(fixture)
            result[kCGWindowLayer as String] = info[kCGWindowLayer as String]
            return result
        }
        let sorted = onScreen.sorted { lhs, rhs in
            func index(_ info: [String: Any]) -> Int {
                let id = info[kCGWindowNumber as String] as? CGWindowID
                let original = fixtures.first { ($0.reportedID ?? $0.id) == id }?.id
                return original.flatMap { stacking.firstIndex(of: $0) } ?? Int.max
            }
            return index(lhs) < index(rhs)
        }
        return (sorted + local) as CFArray
    }
}
func add(_ id: CGWindowID, pid: pid_t, onScreen: Bool = true, minimized: Bool = false, fullScreen: Bool = false, settable: Bool = true, succeeds: Bool = true, layer: Int = 0) {
    let element = ApplicationServices.AXUIElementCreateApplication(pid_t(id + 10000))
    fixtures.append(Fixture(id: id, pid: pid, element: element, minimized: minimized, fullScreen: fullScreen, settable: settable, succeeds: succeeds))
    stacking.append(id)
    if onScreen {
        visible.append([kCGWindowOwnerPID as String: pid, kCGWindowNumber as String: id,
                        kCGWindowLayer as String: layer, kCGWindowAlpha as String: 1.0])
    }
}
func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
func click(expectedChanges: Int) {
    waiting = 0
    gate = DispatchSemaphore(value: 0)
    ShowDesktop.shared.toggle()
    let deadline = Date().addingTimeInterval(5)
    while locked({ waiting }) < expectedChanges && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.005))
    }
    let arrivals = locked { waiting }
    // A click during a pending batch must not launch another minimize/restore operation.
    if expectedChanges > 0 { ShowDesktop.shared.toggle() }
    for _ in 0..<max(expectedChanges, arrivals) { gate.signal() }
    require(arrivals == expectedChanges, "all \(expectedChanges) requests must start before any finishes; got \(arrivals)")
    while ShowDesktop.shared.isBusy && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.005))
    }
    require(!ShowDesktop.shared.isBusy, "batch timed out")
    require(locked { !covered }, "always remove covers")
}
let eligible: Set<CGWindowID> = [1, 2, 9, 10, 11]
// Real AppKit windows without a backing window have number -1. Include our own PID in the simulated window list
// so production discovery scans NSApp.windows, as it does with the real taskbar and its hidden helper panels.
let testApplication = NSApplication.shared
testApplication.setActivationPolicy(.prohibited)
let deferredWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                              styleMask: [.titled, .miniaturizable], backing: .buffered, defer: true)
require(deferredWindow.windowNumber == -1, "regression fixture must have no window-server ID")
require(testApplication.windows.contains(deferredWindow), "regression fixture must be included in local discovery")
visible.append([kCGWindowOwnerPID as String: ProcessInfo.processInfo.processIdentifier,
                kCGWindowNumber as String: CGWindowID(123456), kCGWindowLayer as String: 0])
add(1, pid: 200)
add(2, pid: 200)
add(9, pid: 200)
add(10, pid: 200)
fixtures[fixtures.firstIndex { $0.id == 10 }!].replacesElementOnChange = true
fixtures[fixtures.firstIndex { $0.id == 10 }!].renumbersOnChange = true
add(11, pid: 201)
fixtures[fixtures.firstIndex { $0.id == 11 }!].acknowledgesChange = false // Applied, but reply times out.
add(3, pid: 202, onScreen: false, minimized: true)
add(4, pid: 203, onScreen: false) // Hidden or on another Space.
add(5, pid: 204, fullScreen: true)
add(6, pid: 205, settable: false)
add(7, pid: 206, succeeds: false)
add(8, pid: 207, layer: 25)
add(12, pid: 200, layer: -2147483648) // Finder's desktop AX element has geometry but no usable window ID.
fixtures[fixtures.firstIndex { $0.id == 12 }!].reportedID = 0
Permissions.accessibility = false
click(expectedChanges: 0)
require(Permissions.requested && changed.isEmpty, "request permission without changing windows")
Permissions.accessibility = true
failCapture = true
click(expectedChanges: 0)
require(changed.isEmpty, "capture failure must not change windows")
failCapture = false
click(expectedChanges: 5)
require(Set(changed.map(\.0)) == eligible && changed.allSatisfy(\.1), "minimize supported visible windows")
require(coverExcludedIDs == eligible.union([6, 7]), "show the desktop before minimizing; exclude every target, including fallback windows")
let savedScene = capturedScene
require(savedScene != nil, "save the pre-minimize scene in the batch")
require(hiddenApps == [205, 206], "non-minimizable or failed windows must be persistently hidden and remembered")
// Desktop/app activation must not restore anything. The windows remain truly minimized.
NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
require(fixtures.filter { eligible.contains($0.id) }.allSatisfy(\.minimized), "desktop activation must not restore windows")
// Simulate an app replacing its Accessibility objects when minimized. The stable window ID is unchanged.
fixtures[fixtures.firstIndex { $0.id == 9 }!].element = ApplicationServices.AXUIElementCreateApplication(20009)
fixtures[fixtures.firstIndex { $0.id == 1 }!].minimized = false // Manually restored.
fixtures[fixtures.firstIndex { $0.id == 2 }!].succeeds = false // Temporary restore failure.
changed = []
click(expectedChanges: 3)
require(coverExcludedIDs.isEmpty, "restore must use the saved window scene without excluding its targets")
require(restoredScene == savedScene, "restore must present this batch's saved window scene immediately")
require(Set(changed.map(\.0)) == [9, 10, 11] && changed.allSatisfy { !$0.1 }, "restore only this batch's still-minimized windows")
require(hiddenApps.isEmpty, "restore must unhide the fallback apps")
require(fixtures.first { $0.id == 11 }!.placement == CGRect(x: 330, y: 100, width: 600, height: 400), "refresh must not overwrite the original frame with a drifted restore frame")
require(Array(raised.suffix(6)) == [7, 6, 11, 10, 9, 1], "rebuild the entire stacking order, including unsupported windows, from back to front")
require(fixtures.first { $0.id == 3 }!.minimized, "previously minimized windows must remain minimized")
fixtures[fixtures.firstIndex { $0.id == 2 }!].succeeds = true
changed = []
click(expectedChanges: 1)
require(restoredScene == nil, "release the full scene before retrying only a partially restored batch")
require(changed.map(\.0) == [2] && !changed[0].1, "retry failed restores")
require(Array(raised.suffix(7)) == [7, 6, 11, 10, 9, 2, 1], "a retry must retain the full original order, including already restored windows")
click(expectedChanges: 5)
SkyLight.activeSpace = 2
let originalVisible = visible
visible = []
changed = []
click(expectedChanges: 0)
require(changed.isEmpty, "another Space must not restore the first Space's windows")
SkyLight.activeSpace = 1
visible = originalVisible
click(expectedChanges: 5)
require(Set(changed.map(\.0)) == eligible && changed.allSatisfy { !$0.1 }, "restore this Space's batch together")
require(SkyLight.focused.last == 1, "return focus to the original front window after the batch")
click(expectedChanges: 5)
fixtures[fixtures.firstIndex { $0.id == 2 }!].closed = true
changed = []
click(expectedChanges: 4)
require(Set(changed.map(\.0)) == eligible.subtracting([2]), "closed windows must not block the surviving windows")
SkyLight.visibleSpacesOverride = [1, 2]
SkyLight.activeSpace = 1
changed = []
click(expectedChanges: 4)
SkyLight.activeSpace = 2 // Focus moves to another display; visible desktops have not changed.
changed = []
click(expectedChanges: 4)
require(Set(changed.map(\.0)) == eligible.subtracting([2]) && changed.allSatisfy { !$0.1 }, "focus changes must not lose the saved batch")
require(hiddenApps.isEmpty, "no fallback app may be forgotten after restore")
require(!deferredWindow.isMiniaturized, "unbacked local windows must be ignored")
// Reproduce a hidden app reporting true immediately after unhide but becoming visible before restore finishes.
// Every subsequent click must alternate; an empty hidden-app retry must never consume a minimize click.
unhideDelay = 0.1
for _ in 0..<3 {
    changed = []
    click(expectedChanges: 4)
    require(changed.allSatisfy(\.1), "the click following a complete restore must minimize immediately")
    changed = []
    click(expectedChanges: 4)
    require(changed.allSatisfy { !$0.1 } && hiddenApps.isEmpty, "delayed unhide must complete in the restore click")
}
unhideDelay = 0
// A genuinely hidden app still gets its retry, unlike a stale early acknowledgement.
click(expectedChanges: 4)
failedUnhides = [205]
click(expectedChanges: 4)
require(hiddenApps == [205], "keep a genuine unhide failure pending")
failedUnhides = []
click(expectedChanges: 0)
require(hiddenApps.isEmpty, "retry the still-hidden app without minimizing restored windows")
changed = []
click(expectedChanges: 4)
require(changed.allSatisfy(\.1), "return to minimizing after a genuine unhide retry succeeds")
click(expectedChanges: 4)
// A timed-out app can recover between clicks too. Reconcile that retry before choosing the next action.
click(expectedChanges: 4)
failedUnhides = [205]
click(expectedChanges: 4)
require(hiddenApps == [205], "late-recovery fixture must really still be hidden at the end of restore")
failedUnhides = []
_ = locked { hiddenApps.remove(205) }
changed = []
click(expectedChanges: 4)
require(changed.allSatisfy(\.1), "a restore that completes between clicks must not consume the next minimize click")
click(expectedChanges: 4)
print("PASS: delayed unhide acknowledgements, immediate minimize after restore, late recovery between clicks, genuine unhide failure retry")
print("PASS: non-minimizable windows, removed CG surfaces, renumbered windows, visible-state verification, timed-out acknowledgements, refreshed window objects, display focus changes, unbacked AppKit window IDs, covered queued animations, capture failure, concurrent minimize and restore (including same-app windows), persistent desktop behavior, permissions, filtering, retry, Spaces, focus, closed windows, repeat-click guard")
