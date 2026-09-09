import ApplicationServices
import Foundation

/// Owns an `AXObserver` for one process and forwards its notifications to a closure on the main actor.
///
/// The run-loop source is registered in the common modes so notifications keep arriving while
/// a menu is open, and it is removed again when the handle is deallocated.
@MainActor
final class AXObserverHandle {
    typealias Handler = @MainActor (_ notification: String, _ element: AXElement) -> Void

    let pid: pid_t
    private let observer: AXObserver
    private let registration: RunLoopSourceRegistration
    private let handler: Handler

    init(pid: pid_t, handler: @escaping Handler) throws {
        var created: AXObserver?
        let error = AXObserverCreate(pid, axObserverCallback, &created)
        guard error == .success, let observer = created else {
            throw AXAccessError(code: error, operation: "AXObserverCreate(\(pid))")
        }
        self.pid = pid
        self.observer = observer
        self.handler = handler
        self.registration = RunLoopSourceRegistration(source: AXObserverGetRunLoopSource(observer))
    }

    /// Subscribes to `notification` on `element`. Returns `false` (after logging nothing) when the
    /// element does not support it or the subscription already exists.
    @discardableResult
    func add(_ notification: String, to element: AXElement) throws -> Bool {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let error = AXObserverAddNotification(observer, element.raw, notification as CFString, refcon)
        switch error {
        case .success:
            return true
        case .notificationAlreadyRegistered, .notificationUnsupported:
            return false
        default:
            throw AXAccessError(code: error, operation: "AXObserverAddNotification(\(notification))")
        }
    }

    func remove(_ notification: String, from element: AXElement) {
        AXObserverRemoveNotification(observer, element.raw, notification as CFString)
    }

    fileprivate func dispatch(_ notification: String, element: AXUIElement) {
        handler(notification, AXElement(raw: element))
    }
}

/// Keeps a run-loop source registered on the main run loop for as long as the object lives.
private final class RunLoopSourceRegistration {
    private let source: CFRunLoopSource

    init(source: CFRunLoopSource) {
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    deinit {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
}

/// C entry point; `refcon` carries the unretained `AXObserverHandle`.
private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let handle = Unmanaged<AXObserverHandle>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    nonisolated(unsafe) let element = element
    // AXObserver callbacks are delivered on the run loop the source was added to, i.e. the main run loop.
    MainActor.assumeIsolated {
        handle.dispatch(name, element: element)
    }
}
