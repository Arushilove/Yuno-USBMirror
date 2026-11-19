import Foundation
import Network

/// iPhone par chhota TCP server. PC, usbmuxd ke through is port se connect karta hai.
/// Har message: 4-byte big-endian length + H.264 (Annex B) data.
final class StreamServer {
    var onClientConnected: (() -> Void)?
    var onNeedKeyFrame: (() -> Void)?

    private let queue = DispatchQueue(label: "usbmirror.server")
    private var listener: NWListener?
    private var connection: NWConnection?
    private var pending = 0                      // queue me atke hue sends (sirf `queue` par chhuo)
    private let maxPending = 3

    func start(port: UInt16) throws {
        guard let p = NWEndpoint.Port(rawValue: port) else { return }
        let l = try NWListener(using: .tcp, on: p)
        l.newConnectionHandler = { [weak self] conn in
            guard let self = self else { return }
            self.connection?.cancel()
            self.connection = conn
            self.pending = 0
            conn.stateUpdateHandler = { [weak self] state in
                if case .ready = state { self?.onClientConnected?() }
            }
            conn.start(queue: self.queue)
        }
        l.start(queue: queue)
        listener = l
    }

    func send(_ data: Data, isKeyFrame: Bool) {
        queue.async { [weak self] in
            guard let self = self, let conn = self.connection, conn.state == .ready else { return }

            // PC dheema hai? Purane frames girao, naya keyframe maango (latency na badhe).
            if self.pending >= self.maxPending && !isKeyFrame {
                self.onNeedKeyFrame?()
                return
            }

            var length = UInt32(data.count).bigEndian
            var packet = Data(bytes: &length, count: 4)
            packet.append(data)

            self.pending += 1
            conn.send(content: packet, completion: .contentProcessed { [weak self] _ in
                self?.pending -= 1
            })
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.connection?.cancel()
            self?.listener?.cancel()
            self?.connection = nil
            self?.listener = nil
        }
    }
}
