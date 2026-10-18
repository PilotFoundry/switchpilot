import CoreAudio
import Foundation

/// Capability-aware view of the current default output device. Some outputs
/// (notably HDMI/DisplayPort audio) expose no software volume/mute controls;
/// callers must render that as unsupported instead of pretending to control it.
public struct AudioOutputDevice: Equatable, Sendable {
    public let deviceID: AudioObjectID
    public let name: String
    public let supportsVolume: Bool
    public let supportsMute: Bool
    public let volume: Double?
    public let muted: Bool?
    public let message: String?

    public var isAvailable: Bool { deviceID != 0 }

    public init(
        deviceID: AudioObjectID,
        name: String,
        supportsVolume: Bool,
        supportsMute: Bool,
        volume: Double?,
        muted: Bool?,
        message: String?
    ) {
        self.deviceID = deviceID
        self.name = name
        self.supportsVolume = supportsVolume
        self.supportsMute = supportsMute
        self.volume = volume
        self.muted = muted
        self.message = message
    }
}

public enum AudioOutput {
    private static let outputScope = kAudioObjectPropertyScopeOutput

    public static func read() -> AudioOutputDevice {
        guard let device = defaultOutputDevice() else {
            return AudioOutputDevice(deviceID: 0, name: "无输出设备", supportsVolume: false,
                                     supportsMute: false, volume: nil, muted: nil,
                                     message: "未找到默认输出设备")
        }
        let volumeElement = supportedElement(device, selector: kAudioDevicePropertyVolumeScalar, scope: outputScope)
        let muteElement = supportedElement(device, selector: kAudioDevicePropertyMute, scope: outputScope)
        let volume = volumeElement.flatMap { readFloat32(device, selector: kAudioDevicePropertyVolumeScalar, scope: outputScope, element: $0) }
        let muted = muteElement.flatMap { readUInt32(device, selector: kAudioDevicePropertyMute, scope: outputScope, element: $0) }
        let message: String?
        if volume == nil && muted == nil {
            message = "当前输出设备不支持系统音量/静音控制"
        } else {
            message = nil
        }
        return AudioOutputDevice(
            deviceID: device,
            name: deviceName(device),
            supportsVolume: volume != nil,
            supportsMute: muted != nil,
            volume: volume.map { Double($0) },
            muted: muted.map { $0 != 0 },
            message: message)
    }

    public static func setVolume(_ value: Double) -> Bool {
        guard let device = defaultOutputDevice(),
              let element = supportedElement(device, selector: kAudioDevicePropertyVolumeScalar, scope: outputScope) else {
            return false
        }
        let clamped = Float32(max(0, min(1, value)))
        return writeFloat32(device, selector: kAudioDevicePropertyVolumeScalar, scope: outputScope, element: element, value: clamped)
    }

    public static func setMuted(_ muted: Bool) -> Bool {
        guard let device = defaultOutputDevice(),
              let element = supportedElement(device, selector: kAudioDevicePropertyMute, scope: outputScope) else {
            return false
        }
        return writeUInt32(device, selector: kAudioDevicePropertyMute, scope: outputScope, element: element, value: muted ? 1 : 0)
    }

    public static func toggleMuted() -> Bool {
        let state = read()
        guard let muted = state.muted else { return false }
        return setMuted(!muted)
    }

    // MARK: - CoreAudio helpers

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != 0 else { return nil }
        return device
    }

    private static func deviceName(_ device: AudioObjectID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name)
        guard status == noErr else { return "未知输出设备" }
        return name as String
    }

    private static func supportedElement(
        _ device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyElement? {
        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
            if AudioObjectHasProperty(device, &address) {
                return element
            }
        }
        return nil
    }

    private static func readUInt32(
        _ device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func readFloat32(
        _ device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Float32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func writeUInt32(
        _ device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement,
        value: UInt32
    ) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var mutableValue = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutableValue) == noErr
    }

    private static func writeFloat32(
        _ device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement,
        value: Float32
    ) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var mutableValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutableValue) == noErr
    }
}
