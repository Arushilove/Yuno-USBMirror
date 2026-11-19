import ReplayKit

/// ReplayKit se screen frames milte hain -> H.264 encode -> USB (TCP tunnel) par bhejo.
class SampleHandler: RPBroadcastSampleHandler {
    static let port: UInt16 = 5000      // PC par --port se match hona chahiye

    private let server = StreamServer()
    private let encoder = H264Encoder()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        encoder.onEncoded = { [weak self] data, isKey in
            self?.server.send(data, isKeyFrame: isKey)
        }
        server.onClientConnected = { [weak self] in self?.encoder.requestKeyFrame() }
        server.onNeedKeyFrame = { [weak self] in self?.encoder.requestKeyFrame() }

        do {
            try server.start(port: SampleHandler.port)
        } catch {
            finishBroadcastWithError(NSError(
                domain: "USBMirror", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Server start nahi hua: \(error.localizedDescription)"]))
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        encoder.encode(pixelBuffer, pts: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }

    override func broadcastFinished() {
        server.stop()
        encoder.stop()
    }
}
