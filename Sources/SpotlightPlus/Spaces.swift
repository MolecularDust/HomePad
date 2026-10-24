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
    private typealias PostEvent = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt8>) -> Int32

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

    /// The Spaces a window belongs to. Empty for windows that belong to none: the hidden helper windows many
    /// apps keep around (DaVinci Resolve has dozens).
    static func spaces(of window: CGWindowID) -> [Int] {
        guard let connection, let function = symbol("CGSCopySpacesForWindows", as: SpacesForWindows.self),
              let result = function(connection, 7, [window] as CFArray)?.takeRetainedValue() else { return [] }
        return result as? [Int] ?? []
    }

    /// Brings one specific window to the front, switching to its Space if it's on another one.
    @discardableResult
    static func focus(window: CGWindowID, pid: pid_t) -> Bool {
        guard let processForPID = symbol("GetProcessForPID", as: ProcessForPID.self),
              let setFront = symbol("_SLPSSetFrontProcessWithOptions", as: SetFrontProcess.self),
              let postEvent = symbol("SLPSPostEventRecordTo", as: PostEvent.self) else { return false }
        var psn: (UInt32, UInt32) = (0, 0)
        return withUnsafeMutablePointer(to: &psn) { pointer -> Bool in
            let psn = UnsafeMutableRawPointer(pointer)
            guard processForPID(pid, psn) == 0, setFront(psn, window, 0x200) == 0 else { return false }
            // Two event records tell the window server to make that window the key window.
            var bytes = [UInt8](repeating: 0, count: 0xf8)
            bytes[0x04] = 0xf8
            bytes[0x3a] = 0x10
            withUnsafeBytes(of: window.littleEndian) { for (i, b) in $0.enumerated() { bytes[0x3c + i] = b } }
            for i in 0x20..<0x30 { bytes[i] = 0xff }
            bytes[0x08] = 0x01
            _ = postEvent(psn, &bytes)
            bytes[0x08] = 0x02
            _ = postEvent(psn, &bytes)
            return true
        }
    }
}
