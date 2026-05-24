//
//  ComponentLayoutService.swift
//  YumikoToys
//
//  组件布局管理服务
//

import Foundation
import Combine

/// 组件布局服务协议
protocol ComponentLayoutServiceProtocol: ServiceLifecycle {
    var layoutsPublisher: AnyPublisher<[ComponentLayout], Never> { get }
    func loadLayouts() -> [ComponentLayout]
    func saveLayouts(_ layouts: [ComponentLayout])
    func updateLayout(_ layout: ComponentLayout)
    func toggleVisibility(for type: ComponentType)
    func moveLayout(from source: Int, to destination: Int)
    func resetToDefault()
}

/// 组件布局服务实现
@MainActor
final class ComponentLayoutService: ComponentLayoutServiceProtocol {
    
    // MARK: - Properties
    
    private let storageKey = "yumikotoys.componentLayouts"
    private let storageService: StorageServiceProtocol
    private let migrationService: SettingsMigrationService
    
    private var layoutsSubject = CurrentValueSubject<[ComponentLayout], Never>([])
    
    var layoutsPublisher: AnyPublisher<[ComponentLayout], Never> {
        layoutsSubject.eraseToAnyPublisher()
    }
    
    var currentLayouts: [ComponentLayout] {
        layoutsSubject.value
    }
    
    var serviceName: String { "ComponentLayoutService" }
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol, migrationService: SettingsMigrationService) {
        self.storageService = storageService
        self.migrationService = migrationService
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        // 执行迁移（如果需要）
        await migrationService.migrateIfNeeded()
        
        // 加载布局
        let layouts = loadLayouts()
        layoutsSubject.send(layouts)
        
        LoggerService.shared.info("ComponentLayoutService initialized with \(layouts.count) layouts")
    }
    
    func start() async {
        // 服务已启动
    }
    
    func stop() {
        LoggerService.shared.info("ComponentLayoutService stopped")
    }
    
    // MARK: - Layout Management
    
    func loadLayouts() -> [ComponentLayout] {
        // 尝试从存储加载
        if let layouts: [ComponentLayout] = storageService.load(forKey: storageKey) {
            // 验证布局完整性
            return validateAndRepairLayouts(layouts)
        }
        
        // 返回默认布局
        return ComponentLayout.defaultLayout
    }
    
    func saveLayouts(_ layouts: [ComponentLayout]) {
        storageService.save(layouts, forKey: storageKey)
        layoutsSubject.send(layouts)
        LoggerService.shared.debug("Saved \(layouts.count) component layouts")
    }
    
    func updateLayout(_ layout: ComponentLayout) {
        var layouts = currentLayouts
        if let index = layouts.firstIndex(where: { $0.type == layout.type }) {
            layouts[index] = layout
            saveLayouts(layouts)
        }
    }
    
    func toggleVisibility(for type: ComponentType) {
        guard type.isOptional else {
            LoggerService.shared.warning("Cannot toggle visibility for required component: \(type)")
            return
        }
        
        var layouts = currentLayouts
        if let index = layouts.firstIndex(where: { $0.type == type }) {
            layouts[index].isVisible.toggle()
            saveLayouts(layouts)
            LoggerService.shared.info("Toggled visibility for \(type.displayName): \(layouts[index].isVisible)")
        }
    }
    
    func moveLayout(from source: Int, to destination: Int) {
        var layouts = currentLayouts
        guard source >= 0, source < layouts.count,
              destination >= 0, destination < layouts.count else {
            return
        }
        
        // 移动元素
        let layout = layouts.remove(at: source)
        layouts.insert(layout, at: destination)
        
        // 更新排序索引
        for (index, _) in layouts.enumerated() {
            layouts[index].sortOrder = index
        }
        
        saveLayouts(layouts)
        LoggerService.shared.info("Moved layout from \(source) to \(destination)")
    }
    
    func resetToDefault() {
        saveLayouts(ComponentLayout.defaultLayout)
        LoggerService.shared.info("Reset component layouts to default")
    }
    
    // MARK: - Private Methods
    
    /// 验证并修复布局
    private func validateAndRepairLayouts(_ layouts: [ComponentLayout]) -> [ComponentLayout] {
        var result = layouts
        let allTypes = Set(ComponentType.allCases)
        var existingTypes = Set<ComponentType>()
        
        // 检查现有布局
        for layout in result {
            existingTypes.insert(layout.type)
        }
        
        // 添加缺失的组件类型
        let missingTypes = allTypes.subtracting(existingTypes)
        for type in missingTypes {
            let newLayout = ComponentLayout(
                type: type,
                isVisible: true,
                sortOrder: result.count
            )
            result.append(newLayout)
            LoggerService.shared.info("Added missing component layout: \(type.displayName)")
        }
        
        // 确保核心组件可见
        for index in result.indices {
            if !result[index].type.isOptional && !result[index].isVisible {
                result[index].isVisible = true
                LoggerService.shared.info("Forced visibility for required component: \(result[index].type.displayName)")
            }
        }
        
        // 重新排序
        result.sort { $0.sortOrder < $1.sortOrder }
        for (index, _) in result.enumerated() {
            result[index].sortOrder = index
        }
        
        return result
    }
}
