import Foundation
import VideoToolbox

/// Screen ke pixel buffers ko hardware H.264 me encode karta hai aur Annex B format me deta hai
/// (har keyframe se pehle SPS/PPS lagakar), jise PC par FFmpeg seedha decode kar leta hai.
final class H264Encoder {
    /// (encoded data, keyframe hai?)
    var onEncoded: ((Data, Bool) -> Void)?

    private var session: VTCompressionSession?
    private var width: Int32 = 0
    private var height: Int32 = 0
    private let lock = NSLock()
    private var needKeyFrame = true
    private let startCode: [UInt8] = [0, 0, 0, 1]

    func requestKeyFrame() {
        lock.lock(); needKeyFrame = true; lock.unlock()
    }

    func encode(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
        let w = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let h = Int32(CVPixelBufferGetHeight(pixelBuffer))
        if session == nil || w != width || h != height {
            createSession(width: w, height: h)
        }
        guard let session = session else { return }

        lock.lock()
        let force = needKeyFrame
        needKeyFrame = false
        lock.unlock()
        let props: CFDictionary? = force ? [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary : nil

        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: props,
            infoFlagsOut: nil
        ) { [weak self] status, _, sampleBuffer in
            guard status == noErr, let sampleBuffer = sampleBuffer else { return }
            self?.handle(sampleBuffer)
        }
    }

    func stop() {
        if let s = session {
            VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(s)
        }
        session = nil
    }

    // MARK: - Private

    private func createSession(width w: Int32, height h: Int32) {
        stop()
        width = w
        height = h

        var s: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: w, height: h,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil, imageBufferAttributes: nil,
            compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
            compressionSessionOut: &s)
        guard status == noErr, let session = s else { return }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)   // B-frames nahi = kam latency
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 8_000_000 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 30 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 2 as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)
        self.session = session
    }

    private func handle(_ sb: CMSampleBuffer) {
        // Keyframe hai ya nahi
        var isKey = true
        if let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[CFString: Any]],
           let first = arr.first, let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool {
            isKey = !notSync
        }

        var out = Data()

        // Keyframe se pehle SPS aur PPS
        if isKey, let fmt = CMSampleBufferGetFormatDescription(sb) {
            var count = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                fmt, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil,
                parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
            for i in 0..<count {
                var ptr: UnsafePointer<UInt8>?
                var size = 0
                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    fmt, parameterSetIndex: i, parameterSetPointerOut: &ptr, parameterSetSizeOut: &size,
                    parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
                if let ptr = ptr {
                    out.append(contentsOf: startCode)
                    out.append(ptr, count: size)
                }
            }
        }

        // AVCC (length-prefixed) -> Annex B (start-code)
        guard let block = CMSampleBufferGetDataBuffer(sb) else { return }
        var total = 0
        var base: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                          totalLengthOut: &total, dataPointerOut: &base) == noErr,
              let basePtr = base else { return }

        var offset = 0
        while offset + 4 <= total {
            var nalLen: UInt32 = 0
            memcpy(&nalLen, basePtr + offset, 4)
            nalLen = CFSwapInt32BigToHost(nalLen)
            offset += 4
            let n = Int(nalLen)
            guard n > 0, offset + n <= total else { break }
            out.append(contentsOf: startCode)
            out.append(Data(bytes: basePtr + offset, count: n))
            offset += n
        }

        onEncoded?(out, isKey)
    }
}
