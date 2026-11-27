import AppKit
import ScreenCaptureKit
import CoreImage

/// Show the destination scene before the Dock finishes its per-window animation queue. The pre-minimize scene is
/// retained only in the owning restore batch, in memory, so its windows can reappear together on the next click.
@MainActor
final class DesktopTransition {
    struct Scene {
        fileprivate let frames: [Frame]
    }
    fileprivate struct Frame {
        let displayID: CGDirectDisplayID
        let rect: NSRect
        let image: CGImage
    }
    private var panels: [NSPanel] = []
    private var watchdog: Timer?

    /// Returns the original scene for a new minimize batch. A saved restore scene needs no new screen capture.
    func begin(excludingWindowIDs: Set<CGWindowID>, restoring scene: Scene?) async throws -> Scene? {
        if let scene, matchesCurrentDisplays(scene) {
            present(scene)
            return nil
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let excluded = content.windows.filter { excludingWindowIDs.contains($0.windowID) }
        var snapshots: [Frame] = []
        var original: [Frame] = []
        // Capture every display before presenting any cover, so a cover cannot get into another display's snapshot.
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let display = content.displays.first(where: { $0.displayID == id }) else { throw CaptureError.noDisplay }
            let configuration = SCStreamConfiguration()
            configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
            configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
            configuration.showsCursor = false
            if #available(macOS 14, *) { configuration.ignoreShadowsDisplay = false }
            let filter = SCContentFilter(display: display, excludingWindows: excluded)
            if !excludingWindowIDs.isEmpty {
                // Capture both scenes concurrently before changing any windows. Saving the first scene here avoids
                // a capture round trip on restore and avoids showing the empty desktop through the restore queue.
                async let before = captureOriginal(screen: screen, display: display, configuration: configuration)
                async let after = capture(filter: filter, configuration: configuration)
                let images = try await (before, after)
                original.append(Frame(displayID: id, rect: screen.frame, image: images.0))
                snapshots.append(Frame(displayID: id, rect: screen.frame, image: images.1))
            } else {
                let image = try await capture(filter: filter, configuration: configuration)
                snapshots.append(Frame(displayID: id, rect: screen.frame, image: image))
            }
        }
        guard !snapshots.isEmpty else { throw CaptureError.noDisplay }
        present(Scene(frames: snapshots))
        return original.isEmpty ? nil : Scene(frames: original)
    }

    private func capture(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        if #available(macOS 14, *) {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        }
        return try await FirstFrameCapture.capture(filter: filter, configuration: configuration)
    }

    private func captureOriginal(screen: NSScreen, display: SCDisplay, configuration: SCStreamConfiguration) async throws -> CGImage {
        if #available(macOS 15.2, *), let primary = NSScreen.screens.first {
            // Preserve the final on-screen composition, including shadow intensity and the display's color
            // appearance. Re-rendering an unfiltered display through the stream API can make its shadows lighter,
            // so they visibly pop when the cover is removed even though all windows are already restored.
            let rect = CGRect(x: screen.frame.minX, y: primary.frame.maxY - screen.frame.maxY,
                              width: screen.frame.width, height: screen.frame.height)
            return try await SCScreenshotManager.captureImage(in: rect)
        }
        return try await capture(filter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration)
    }

    private func matchesCurrentDisplays(_ scene: Scene) -> Bool {
        scene.frames.count == NSScreen.screens.count && scene.frames.allSatisfy { frame in
            NSScreen.screens.contains { screen in
                screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == frame.displayID
                    && screen.frame == frame.rect
                    && Int(screen.frame.width * screen.backingScaleFactor) == frame.image.width
                    && Int(screen.frame.height * screen.backingScaleFactor) == frame.image.height
            }
        }
    }

    private func present(_ scene: Scene) {
        for frame in scene.frames {
            let panel = CoverPanel(contentRect: frame.rect, styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            // A fully opaque cover marks the live windows as occluded. Browser renderers then defer their redraw
            // until this panel disappears, causing a second visible repaint. Keep a tiny transparency so they can
            // finish drawing underneath the saved scene before the handoff.
            panel.isOpaque = false
            panel.alphaValue = 0.999
            panel.hasShadow = false
            panel.animationBehavior = .none
            // Take clicks while the covered windows are changing, without taking keyboard focus.
            panel.ignoresMouseEvents = false
            let view = NSImageView(frame: NSRect(origin: .zero, size: frame.rect.size))
            view.image = NSImage(cgImage: frame.image, size: frame.rect.size)
            view.imageScaling = .scaleAxesIndependently
            panel.contentView = view
            panels.append(panel)
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0
            panels.forEach { $0.orderFrontRegardless() }
        }, completionHandler: nil)
        // Always give the screen back, even if an app stops responding during the operation.
        watchdog = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
    }

    func finishAfterRendering() async {
        // Focus and geometry acknowledgements precede the app's next paint. The non-occluding cover keeps those
        // paints running; leave it up for three 60 Hz frames after the final changes before exposing live content.
        try? await Task.sleep(nanoseconds: 50_000_000)
        finish()
    }

    func finish() {
        watchdog?.invalidate()
        watchdog = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0
            panels.forEach { $0.orderOut(nil) }
        }, completionHandler: nil)
        panels.removeAll()
    }

    private final class CoverPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private enum CaptureError: Error { case noDisplay }
}

/// macOS 13 has ScreenCaptureKit streams but no SCScreenshotManager. Take one complete frame, then stop the stream.
private final class FirstFrameCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var stream: SCStream?

    static func capture(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        let capture = FirstFrameCapture()
        return try await withCheckedThrowingContinuation { continuation in
            capture.continuation = continuation
            let stream = SCStream(filter: filter, configuration: configuration, delegate: capture)
            capture.stream = stream
            do {
                try stream.addStreamOutput(capture, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
                stream.startCapture { error in if let error { capture.complete(.failure(error)) } }
            } catch { capture.complete(.failure(error)) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                capture.complete(.failure(CaptureError.timeout))
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: buffer)
        if let image = CIContext().createCGImage(image, from: image.extent) { complete(.success(image)) }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { complete(.failure(error)) }

    private func complete(_ result: Result<CGImage, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        guard let continuation else { return }
        stream?.stopCapture { _ in }
        continuation.resume(with: result)
    }

    private enum CaptureError: Error { case timeout }
}
