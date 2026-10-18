import CoreAudio
import Foundation

/// Capability-aware view of the default input device. Some microphones (e.g.
/// some headset mics) expose no software mute property; the UI must show that
/// instead of pretending to mute them.
public struct MicrophoneDevice: Equatable, Sendable {
    public let deviceID: AudioObjectID
    public let name: String
    public let supportsMute: Bool
    public let muted: Bool?
    public let message: String?

    public var isAvailable: Bool { deviceID != 0 }

    public init(deviceID: AudioObjectID, name: String, supportsMute: Bool, muted: Bool?, message: String?) {
        self.deviceID = deviceID
        self.name = name
        self.supportsMute = supportsMute
        self.muted = muted
        self.message = message
    }
}

public enum Microphone {
    private static let inputScope = kAudioObjectPropertyScopeInput

    public static func read() -> MicrophoneDevice {
        guard let device = defaultInputDevice() else {
            return MicrophoneDevice(deviceID: 0, name: "无输入设备", supportsMute: false,
                                    muted: nil, message: "未找到默认输入设备")
        }
        let element = supportedMuteElement(device)
        let muted = element.flatMap { readMute(device, element: $0) }
        return MicrophoneDevice(
            deviceID: device,
            name: deviceName(device),
            supportsMute: muted != nil,
            muted: muted,
            message: muted == nil ? "当前输入设备不支持系统静音控制" : nil)
    }

    public static func setMuted(_ muted: Bool) -> Bool {
        guard let device = defaultInputDevice(),
              let element = supportedMuteElement(device) else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: inputScope,
            mElement: element)
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    public static func toggleMuted() -> Bool {
        guard let current = read().muted else { return false }
        return setMuted(!current)
    }

    // MARK: - CoreAudio helpers

    private static func defaultInputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
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
        guard status == noErr else { return "未知输入设备" }
        return name as String
    }

    private static func supportedMuteElement(_ device: AudioObjectID) -> AudioObjectPropertyElement? {
        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute, mScope: inputScope, mElement: element)
            if AudioObjectHasProperty(device, &address) {
                return element
            }
        }
        return nil
    }

    private static func readMute(_ device: AudioObjectID, element: AudioObjectPropertyElement) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute, mScope: inputScope, mElement: element)
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value != 0 : nil
    }
}
