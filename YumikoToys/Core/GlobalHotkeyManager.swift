//
//  GlobalHotkeyManager.swift
//  YumikoToys
//
//  全局快捷键管理器 (v4.5.0 - 基于 Carbon API 的非 TCC 权限全局监听器)
//

import Foundation
import Carbon
import AppKit

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    private init() {}
    
    func setupHotkey(preset: ScreenshotHotkeyPreset) {
        // Clear old hotkey if any
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
        default:
            return
        }
        
        // Register event handler
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
                    ScreenMediaHelper.shared.captureArea()
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
