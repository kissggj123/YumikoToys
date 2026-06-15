//
//  GlobalHotkeyManager.swift
//  YumikoToys
//
//  全局快捷键管理器 (v5.0.0 - 支持 Fn 键与自定义回调)
//

import Foundation
import Carbon
import AppKit

// Fn key modifier mask (NX_SECONDARYFNMASK = 0x00002000)
private let fnKeyModifier: UInt32 = 0x00002000

// Global handler storage (avoids capturing self in C function pointer)
private nonisolated(unsafe) var hotkeyHandler: (() -> Void)?

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    /// 快捷键触发时的回调
    var onHotkeyTriggered: (() -> Void)? {
        didSet {
            hotkeyHandler = onHotkeyTriggered
        }
    }
    
    private init() {}
    
    func setupHotkey(preset: ScreenshotHotkeyPreset) {
        unregisterHotkey()
        
        guard preset != .none else { return }
        
        let keyCode: UInt32
        let modifiers: UInt32
        
        switch preset {
        case .cmdShift6:
            keyCode = 0x16 // Key '6'
            modifiers = UInt32(cmdKey | shiftKey)
        case .optionS:
            keyCode = 0x01 // Key 'S'
            modifiers = UInt32(optionKey)
        case .controlShiftS:
            keyCode = 0x01 // Key 'S'
            modifiers = UInt32(controlKey | shiftKey)
        case .fnF1:
            keyCode = UInt32(kVK_F1)
            modifiers = fnKeyModifier
        case .fnF2:
            keyCode = UInt32(kVK_F2)
            modifiers = fnKeyModifier
        case .fnF3:
            keyCode = UInt32(kVK_F3)
            modifiers = fnKeyModifier
        case .fnF4:
            keyCode = UInt32(kVK_F4)
            modifiers = fnKeyModifier
        case .fnF5:
            keyCode = UInt32(kVK_F5)
            modifiers = fnKeyModifier
        case .fnF6:
            keyCode = UInt32(kVK_F6)
            modifiers = fnKeyModifier
        case .fnF7:
            keyCode = UInt32(kVK_F7)
            modifiers = fnKeyModifier
        case .fnF8:
            keyCode = UInt32(kVK_F8)
            modifiers = fnKeyModifier
        case .fnF9:
            keyCode = UInt32(kVK_F9)
            modifiers = fnKeyModifier
        case .fnF10:
            keyCode = UInt32(kVK_F10)
            modifiers = fnKeyModifier
        case .fnF11:
            keyCode = UInt32(kVK_F11)
            modifiers = fnKeyModifier
        case .fnF12:
            keyCode = UInt32(kVK_F12)
            modifiers = fnKeyModifier
        case .controlShift4:
            keyCode = 0x1D // Key '4'
            modifiers = UInt32(controlKey | shiftKey)
        case .controlShift3:
            keyCode = 0x14 // Key '3'
            modifiers = UInt32(controlKey | shiftKey)
        default:
            return
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerBlock: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr && hotKeyID.id == 1001 {
                DispatchQueue.main.async {
                    if let handler = hotkeyHandler {
                        handler()
                    } else {
                        ScreenMediaHelper.shared.captureArea()
                    }
                }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        
        if status == noErr {
            let hotKeyID = EventHotKeyID(signature: OSType(1337), id: 1001)
            var gMyHotKeyRef: EventHotKeyRef?
            
            let registerStatus = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &gMyHotKeyRef
            )
            
            if registerStatus == noErr {
                self.hotKeyRef = gMyHotKeyRef
                LoggerService.shared.info("Global hotkey registered successfully for preset: \(preset.rawValue)")
            } else {
                LoggerService.shared.error("Failed to register global hotkey: \(registerStatus)")
            }
        } else {
            LoggerService.shared.error("Failed to install event handler: \(status)")
        }
    }
    
    func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }
}
