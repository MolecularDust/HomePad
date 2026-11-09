import AppKit
import AudioToolbox
import CoreAudio
import CoreWLAN
import IOKit.ps
import Network
import SwiftUI

/// The right-hand end of the taskbar, as on Windows: network, volume, battery and the clock, each with a switch in
/// Settings → Mode → Taskbar.
///
/// The menus macOS shows for these in the menu bar can't be opened from here: on recent macOS its status items carry no
/// names or actions for Accessibility. So the network and battery open their pages in System Settings, and the volume
/// and the clock have small pop-ups of HomePad's own (a slider, a calendar).
enum TaskbarTray {
    static let networkKey = "taskbarShowsNetwork"
    static let volumeKey = "taskbarShowsVolume"
    static let batteryKey = "taskbarShowsBattery"
    static let clockKey = "taskbarShowsClock"

    static func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") { NSWorkspace.shared.open(url) }
    }
}

struct TaskbarTrayView: View {
    @AppStorage(TaskbarTray.networkKey) private var showsNetwork = true
    @AppStorage(TaskbarTray.volumeKey) private var showsVolume = true
    @AppStorage(TaskbarTray.batteryKey) private var showsBattery = true
    @AppStorage(TaskbarTray.clockKey) private var showsClock = true
    @ObservedObject private var battery = BatteryStatus.shared

    var body: some View {
        HStack(spacing: 2) {
            if showsNetwork { NetworkItem() }
            if showsVolume { VolumeItem() }
            if showsBattery && battery.present { BatteryItem() }
            if showsClock { ClockItem() }
        }
        .padding(.trailing, 8)
    }
}

/// One item of the tray: pale square on hover, a name label, a click.
private struct TrayItem<Content: View>: View {
    let label: String
    let action: (NSRect?) -> Void
    @ViewBuilder let content: () -> Content
    @ObservedObject private var drag = TaskbarDrag.shared
    @State private var hovering = false
    @State private var frame = CGRect.zero

    var body: some View {
        content()
            .padding(.horizontal, 7)
            .frame(minWidth: 32, minHeight: 40)
            .background(TaskbarHighlight(on: hovering && drag.item == nil, strong: false))
            .background(FrameReader(frame: $frame))
            .contentShape(Rectangle())
            .onHover { inside in
                hovering = inside
                TaskbarLabel.shared.hover(inside ? label : nil, over: Taskbar.shared.screenRect(frame))
            }
            .onTapGesture {
                TaskbarLabel.shared.hover(nil, over: nil)
                action(Taskbar.shared.screenRect(frame))
            }
    }
}

// MARK: - Network

final class NetworkStatus: ObservableObject {
    static let shared = NetworkStatus()
    enum Kind { case wifi, wired, other, offline }
    @Published private(set) var kind = Kind.other
    /// Wi-Fi signal, 0…1.
    @Published private(set) var strength = 1.0
    private let monitor = NWPathMonitor()
    private var timer: Timer?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.update(path) }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.readStrength() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func update(_ path: NWPath) {
        if path.status != .satisfied { kind = .offline }
        else if path.usesInterfaceType(.wifi) { kind = .wifi }
        else if path.usesInterfaceType(.wiredEthernet) { kind = .wired }
        else { kind = .other }
        readStrength()
    }

    /// The signal is readable without Location permission (only the network's name needs it).
    private func readStrength() {
        guard kind == .wifi, let rssi = CWWiFiClient.shared().interface()?.rssiValue(), rssi != 0 else { return }
        let value = min(1, max(0.05, Double(rssi + 90) / 40))      // -90 dBm weak … -50 dBm full
        if abs(value - strength) > 0.01 { strength = value }
    }
}

private struct NetworkItem: View {
    @ObservedObject private var status = NetworkStatus.shared

    var body: some View {
        TrayItem(label: label, action: { _ in
            TaskbarTray.openSettings(status.kind == .wifi || status.kind == .offline
                                     ? "com.apple.wifi-settings-extension" : "com.apple.Network-Settings.extension")
        }) {
            symbol.font(.system(size: 14))
        }
    }

    private var symbol: Image {
        switch status.kind {
        case .wifi: return Image(systemName: "wifi", variableValue: status.strength)
        case .wired, .other: return Image(systemName: "network")
        case .offline: return Image(systemName: "wifi.slash")
        }
    }

    private var label: String {
        switch status.kind {
        case .wifi: return L("⟦Wi-Fi⟧: connected")
        case .wired: return L("Ethernet: connected")
        case .other: return L("Connected to the internet")
        case .offline: return L("Not connected")
        }
    }
}

// MARK: - Volume

/// The default output's volume and mute, read every second (cheap) and set from the tray.
final class VolumeStatus: ObservableObject {
    static let shared = VolumeStatus()
    @Published private(set) var volume: Float = 0
    @Published private(set) var muted = false
    @Published private(set) var available = false
    private var timer: Timer?

    private init() {
        read()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.read() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private var device: AudioObjectID {
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    func read() {
        let device = self.device
        var volumeAddress = Self.volumeAddress, muteAddress = Self.muteAddress
        var value = Float32(0), size = UInt32(MemoryLayout<Float32>.size)
        let ok = AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &value) == noErr
        var mute = UInt32(0), muteSize = UInt32(MemoryLayout<UInt32>.size)
        let hasMute = AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &muteSize, &mute) == noErr
        if ok != available { available = ok }
        if ok, abs(value - volume) > 0.001 { volume = value }
        if (hasMute && mute != 0) != muted { muted = hasMute && mute != 0 }
    }

    func set(_ new: Float) {
        var value = Float32(min(1, max(0, new)))
        var address = Self.volumeAddress
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if muted && value > 0 { setMuted(false) }
        read()
    }

    func setMuted(_ on: Bool) {
        var value = UInt32(on ? 1 : 0)
        var address = Self.muteAddress
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        read()
    }

    /// The speaker symbol for a level.
    static func symbol(volume: Float, muted: Bool) -> String {
        if muted || volume == 0 { return "speaker.slash" }
        return volume < 0.34 ? "speaker.wave.1" : volume < 0.67 ? "speaker.wave.2" : "speaker.wave.3"
    }
}

private struct VolumeItem: View {
    @ObservedObject private var status = VolumeStatus.shared
    @State private var frame = CGRect.zero

    var body: some View {
        TrayItem(label: status.muted ? L("Muted") : L("Volume: \(Int((status.volume * 100).rounded()))%"),
                 action: { rect in TaskbarFlyout.shared.toggle(.volume, over: rect) { VolumeFlyout() } }) {
            Image(systemName: VolumeStatus.symbol(volume: status.volume, muted: status.muted))
                .font(.system(size: 14))
                .frame(width: 20)
        }
        .background(FrameReader(frame: $frame))
        .onAppear { VolumeScroll.shared.area = { Taskbar.shared.screenRect(frame) } }
    }
}

/// Scrolling over the volume icon changes the volume, in macOS's own steps (1/16).
final class VolumeScroll {
    static let shared = VolumeScroll()
    var area: () -> NSRect? = { nil }
    private var monitor: Any?
    private var pending: CGFloat = 0

    private init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let rect = self.area(), rect.contains(NSEvent.mouseLocation),
                  UserDefaults.standard.object(forKey: TaskbarTray.volumeKey) as? Bool ?? true else { return event }
            self.pending += event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.1 : 1)
            let steps = Int(self.pending)
            if steps != 0 {
                self.pending -= CGFloat(steps)
                VolumeStatus.shared.set(VolumeStatus.shared.volume + Float(steps) / 16)
            }
            return nil
        }
    }
}

private struct VolumeFlyout: View {
    @ObservedObject private var status = VolumeStatus.shared

    var body: some View {
        HStack(spacing: 10) {
            Button { status.setMuted(!status.muted) } label: {
                Image(systemName: VolumeStatus.symbol(volume: status.volume, muted: status.muted))
                    .font(.system(size: 15)).frame(width: 22)
            }
            .buttonStyle(.plain)
            .help(status.muted ? L("Unmute") : L("Mute"))
            Slider(value: Binding(get: { Double(status.volume) }, set: { status.set(Float($0)) }), in: 0...1)
                .frame(width: 200)
            Text(verbatim: "\(Int((status.volume * 100).rounded()))")
                .monospacedDigit().frame(width: 30, alignment: .trailing)
        }
        .padding(16)
    }
}

// MARK: - Battery

final class BatteryStatus: ObservableObject {
    static let shared = BatteryStatus()
    @Published private(set) var present = false
    @Published private(set) var percent = 100
    @Published private(set) var charging = false
    @Published private(set) var pluggedIn = false
    private var source: CFRunLoopSource?

    private init() {
        update()
        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async { BatteryStatus.shared.update() }
        }, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            self.source = source
        }
    }

    func update() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { present = false; return }
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = info[kIOPSMaxCapacityKey] as? Int ?? 100
            present = true
            percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            charging = info[kIOPSIsChargingKey] as? Bool ?? false
            pluggedIn = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return
        }
        present = false
    }
}

private struct BatteryItem: View {
    @ObservedObject private var status = BatteryStatus.shared

    var body: some View {
        TrayItem(label: label, action: { _ in TaskbarTray.openSettings("com.apple.Battery-Settings.extension") }) {
            Image(systemName: symbol).font(.system(size: 15))
        }
    }

    private var symbol: String {
        if status.charging || status.pluggedIn { return "battery.100.bolt" }
        switch status.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private var label: String {
        if status.charging { return L("Battery: \(status.percent)%, charging") }
        if status.pluggedIn { return L("Battery: \(status.percent)%, plugged in") }
        return L("Battery: \(status.percent)%")
    }
}

// MARK: - Clock

private struct ClockItem: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            TrayItem(label: context.date.formatted(date: .complete, time: .omitted),
                     action: { rect in TaskbarFlyout.shared.toggle(.calendar, over: rect) { CalendarFlyout() } }) {
                // The Mac's own time and date formats (HomePad runs in the Mac's language and region).
                VStack(alignment: .trailing, spacing: 1) {
                    Text(context.date.formatted(date: .omitted, time: .shortened))
                    Text(context.date.formatted(date: .numeric, time: .omitted))
                }
                .font(.system(size: 12))
                .monospacedDigit()
            }
        }
    }
}

/// A month, today marked, with arrows to the months around it.
private struct CalendarFlyout: View {
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    private let calendar = Calendar.current

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let first = calendar.component(.weekday, from: month)
        let blanks = (first - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: blanks)
            + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.system(size: 13, weight: .semibold))
            Divider()
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain)
                Button { shift(1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 2), count: 7), spacing: 4) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let today = calendar.isDateInToday(day)
                        Text(verbatim: "\(calendar.component(.day, from: day))")
                            .font(.system(size: 12))
                            .foregroundStyle(today ? Color.white : Color.primary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(today ? Color.accentColor : .clear))
                    } else {
                        Color.clear.frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func shift(_ months: Int) {
        if let new = calendar.date(byAdding: .month, value: months, to: month) { month = new }
    }
}

// MARK: - Pop-ups

/// A small pop-up above the tray (the volume slider, the calendar). A click on its item again, or anywhere else,
/// closes it. It never takes the keyboard, like the taskbar.
final class TaskbarFlyout {
    static let shared = TaskbarFlyout()
    enum Kind { case volume, calendar }
    private var panel: NSPanel?
    private var shown: Kind?
    private var monitors: [Any] = []

    func toggle<Content: View>(_ kind: Kind, over rect: NSRect?, @ViewBuilder content: () -> Content) {
        if shown == kind { close(); return }
        close()
        guard let rect else { return }
        let inside = content()
        let host = NSHostingView(rootView: FlyoutCard { inside }.localized())
        let size = host.fittingSize
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = host
        var origin = NSPoint(x: rect.midX - size.width / 2, y: (Taskbar.shared.frame?.maxY ?? rect.maxY) + 4)
        if let screen = NSScreen.screens.first {
            origin.x = min(max(origin.x, screen.frame.minX + 4), screen.frame.maxX - size.width - 4)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        shown = kind
        // A click outside: in another app (global) or on the taskbar (local; the item's own click toggles instead).
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.panel && event.window !== Taskbar.shared.window { self?.close() }
            return event
        } as Any)
    }

    func close() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        panel?.orderOut(nil)
        panel = nil
        shown = nil
    }
}

private struct FlyoutCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
            .padding(14)            // room for the shadow
    }
}
