import AppKit

/// Private window-server calls (SkyLight) for what no public API offers: which Space a window lives in, and
/// bringing a window to the front when it's on another Space (macOS then switches to that Space).
/// The app isn't sandboxed or sold through the App Store, so private calls are allowed; each one is looked up at
/// run time and the feature quietly does nothing if a symbol ever disappears.
enum SkyLight {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias ActiveSpace = @convention(c) (Int32) -> Int
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutableRawPointer) -> Int32
    private typealias SetFrontProcess = @convention(c) (UnsafeMutableRawPointer, CGWindowID, UInt32) -> Int32
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias PostEvent = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias IsOrderedIn = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<UInt8>) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        // Most are in SkyLight; GetProcessForPID is an older call that lives elsewhere.
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        guard let pointer = (handle.flatMap { dlsym($0, name) }) ?? dlsym(rtldDefault, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    private static let connection = symbol("CGSMainConnectionID", as: MainConnection.self)?()

    /// The Space the screen is showing now.
    static var activeSpace: Int? {
        guard let connection, let function = symbol("CGSGetActiveSpace", as: ActiveSpace.self) else { return nil }
        return function(connection)
    }

    /// All desktops currently visible, independent of which display's app has keyboard focus. Hiding an app can
    /// change activeSpace without changing any visible desktop, so that value alone cannot key a restore batch.
    static var visibleSpaces: [Int] {
        guard let connection, let function = symbol("CGSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpaces.self),
              let displays = function(connection)?.takeRetainedValue() as? [[String: Any]] else {
            return activeSpace.map { [$0] } ?? []
        }
        let spaces = displays.compactMap { display -> Int? in
            guard let current = display["Current Space"] as? [String: Any] else { return nil }
            return current["ManagedSpaceID"] as? Int ?? current["id64"] as? Int
        }
        return spaces.isEmpty ? activeSpace.map { [$0] } ?? [] : Array(Set(spaces)).sorted()
    }

    /// Space id -> its number (1, 2, 3 ...) in Mission Control's order, per display.
    static func spaceNumbers() -> [Int: Int] {
        guard let connection, let function = symbol("CGSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpaces.self),
              let displays = function(connection)?.takeRetainedValue() as? [[String: Any]] else { return [:] }
        var numbers: [Int: Int] = [:]
        for display in displays {
            for (index, space) in ((display["Spaces"] as? [[String: Any]]) ?? []).enumerated() {
                if let id = space["ManagedSpaceID"] as? Int { numbers[id] = index + 1 }
            }
        }
        return numbers
    }

    /// The Spaces a window belongs to. Empty for windows that belong to none: the hidden helper windows many
    /// apps keep around (DaVinci Resolve has dozens).
    static func spaces(of window: CGWindowID) -> [Int] {
        guard let connection, let function = symbol("CGSCopySpacesForWindows", as: SpacesForWindows.self),
              let result = function(connection, 7, [window] as CFArray)?.takeRetainedValue() else { return [] }
        return result as? [Int] ?? []
    }

    /// Whether a window is placed on its Space, shown there when that Space is. Apps keep hidden windows assigned to
    /// a Space too (Opera keeps its address-bar suggestions and an empty panel), and seen from another Space they look
    /// just like real windows there. nil if the call is unavailable.
    static func isOrderedIn(_ window: CGWindowID) -> Bool? {
        guard let connection, let function = symbol("SLSWindowIsOrderedIn", as: IsOrderedIn.self) else { return nil }
        var ordered: UInt8 = 0
        guard function(connection, window, &ordered) == 0 else { return nil }
        return ordered != 0
    }

    /// Brings one specific window to the front, switching to its Space if it's on another one.
    @discardableResult
    static func focus(window: CGWindowID, pid: pid_t) -> Bool {
        setFrontWindow(window, pid: pid, mode: 0x200)
    }

    /// Activates without raising the app's other windows, then makes only the requested window key.
    @discardableResult
    static func raisePreservingOthers(window: CGWindowID, pid: pid_t) -> Bool {
        setFrontWindow(window, pid: pid, mode: 0x400)
    }

    /// Restores app activation without moving any window, including when the desktop originally had focus.
    @discardableResult
    static func activatePreservingWindowOrder(pid: pid_t) -> Bool {
        setFrontWindow(nil, pid: pid, mode: 0x400)
    }

    private static func setFrontWindow(_ window: CGWindowID?, pid: pid_t, mode: UInt32) -> Bool {
        guard let processForPID = symbol("GetProcessForPID", as: ProcessForPID.self),
              let setFront = symbol("_SLPSSetFrontProcessWithOptions", as: SetFrontProcess.self),
              let postEvent = symbol("SLPSPostEventRecordTo", as: PostEvent.self) else { return false }
        var psn: (UInt32, UInt32) = (0, 0)
        return withUnsafeMutablePointer(to: &psn) { pointer -> Bool in
            let psn = UnsafeMutableRawPointer(pointer)
            guard processForPID(pid, psn) == 0, setFront(psn, window ?? 0, mode) == 0 else { return false }
            guard let window else { return true }
            var bytes = [UInt8](repeating: 0, count: 0xf8)
            bytes[0x04] = 0xf8
            bytes[0x3a] = 0x10
            withUnsafeBytes(of: window.littleEndian) { for (i, b) in $0.enumerated() { bytes[0x3c + i] = b } }
            for i in 0x20..<0x30 { bytes[i] = 0xff }
            bytes[0x08] = 0x01
            guard postEvent(psn, &bytes) == 0 else { return false }
            bytes[0x08] = 0x02
            return postEvent(psn, &bytes) == 0
        }
    }
}

/// Accessibility only lists windows on the Space being shown. Windows on other Spaces can still be reached by
/// building their Accessibility elements directly (private calls), which is how window switchers such as AltTab
/// do it: element ids are tried one after another and each window element is matched to its window number.
/// Ids count up as an app creates interface elements, so windows sit at ids in the thousands. Windows found are
/// remembered, and later searches start near the highest id seen.
enum RemoteAX {
    private typealias CreateWithRemoteToken = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let createWithRemoteToken = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementCreateWithRemoteToken")
        .map { unsafeBitCast($0, to: CreateWithRemoteToken.self) }
    private static let getWindow = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")
        .map { unsafeBitCast($0, to: GetWindow.self) }

    /// The window number of a window's Accessibility element (nil if macOS doesn't say).
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard let getWindow, getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    private static let lock = NSLock()
    private static var knownIDs: [pid_t: [CGWindowID: UInt64]] = [:]
    private static var highWater: [pid_t: UInt64] = [:]

    /// The Accessibility element of one window, on any Space. `deep` keeps searching much further (a few
    /// seconds at worst); it is for when the user has clicked something and is waiting for it anyway.
    static func element(for window: CGWindowID, pid: pid_t, deep: Bool = false) -> AXUIElement? {
        guard Permissions.accessibility, createWithRemoteToken != nil, getWindow != nil else { return nil }
        lock.lock()
        let cachedID = knownIDs[pid]?[window]
        let high = highWater[pid] ?? 0
        lock.unlock()

        if let cachedID, let element = windowElement(pid: pid, id: cachedID, expecting: window) { return element }

        let start = high > 500 ? high - 500 : 0          // newer elements have higher ids
        let end = max(high + 10_000, 40_000)
        return scan(pid: pid, ids: start..<end, target: window)
            ?? (start > 0 ? scan(pid: pid, ids: 0..<start, target: window) : nil)
            ?? (deep ? scan(pid: pid, ids: end..<300_000, target: window) : nil)
    }

    private static func token(pid: pid_t, id: UInt64) -> CFData {
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: Int32(pid)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f636f)) { Data($0) })
        token.replaceSubrange(12..<20, with: withUnsafeBytes(of: id) { Data($0) })
        return token as CFData
    }

    private static func windowElement(pid: pid_t, id: UInt64, expecting: CGWindowID? = nil) -> AXUIElement? {
        guard let createWithRemoteToken, let getWindow,
              let element = createWithRemoteToken(token(pid: pid, id: id))?.takeRetainedValue() else { return nil }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard role as? String == kAXWindowRole else { return nil }
        var windowID = CGWindowID(0)
        guard getWindow(element, &windowID) == .success, expecting == nil || windowID == expecting else { return nil }
        return element
    }

    private static func scan(pid: pid_t, ids: Range<UInt64>, target: CGWindowID) -> AXUIElement? {
        guard let getWindow else { return nil }
        for id in ids {
            guard let element = windowElement(pid: pid, id: id) else { continue }
            var windowID = CGWindowID(0)
            guard getWindow(element, &windowID) == .success else { continue }
            lock.lock()
            knownIDs[pid, default: [:]][windowID] = id
            highWater[pid] = max(highWater[pid] ?? 0, id)
            lock.unlock()
            if windowID == target { return element }
        }
        return nil
    }
}
