//
//  AppPickerView.swift
//  YumikoToys
//
//  应用批量选择器 (v4.5.0 - 便捷配置快速启动应用)
//

import SwiftUI

struct AppPickerView: View {
    @Binding var isPresented: Bool
    @ObservedObject var pluginService = PluginService.shared
    
    @State private var scannedApps: [InstalledAppInfo] = []
    @State private var selectedAppNames: Set<String> = []
    @State private var searchQuery = ""
    
    private var groupedApps: [String: [InstalledAppInfo]] {
        let filtered = scannedApps.filter { app in
            searchQuery.isEmpty || app.name.lowercased().contains(searchQuery.lowercased())
        }
        return Dictionary(grouping: filtered, by: { $0.category })
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("从已安装应用中选择")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索已安装应用...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let groups = groupedApps.keys.sorted()
                    if groups.isEmpty {
                        Text("未发现符合条件的应用")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.top, 24)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(groups, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(groupedApps[category] ?? []) { app in
                                        HStack(spacing: 8) {
                                            Toggle(isOn: Binding(
                                                get: { selectedAppNames.contains(app.name) },
                                                set: { isSelected in
                                                    if isSelected {
                                                        selectedAppNames.insert(app.name)
                                                    } else {
                                                        selectedAppNames.remove(app.name)
                                                    }
                                                }
                                            )) {
                                                Text(app.name)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.primary)
                                            }
                                            .toggleStyle(CheckboxToggleStyle())
                                            
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(Color.primary.opacity(0.02))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Spacer()
                
                Button("全选") {
                    let filtered = scannedApps.filter { app in
                        searchQuery.isEmpty || app.name.lowercased().contains(searchQuery.lowercased())
                    }
                    selectedAppNames = Set(filtered.map { $0.name })
                }
                .buttonStyle(.plain)
                
                Button("清除选择") {
                    selectedAppNames.removeAll()
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    for name in selectedAppNames {
                        pluginService.addQuickLaunchApp(name: name)
                    }
                    isPresented = false
                }) {
                    Text("确认添加 (\(selectedAppNames.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "007AFF"))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(selectedAppNames.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 480, height: 400)
        .onAppear {
            scannedApps = AppScanner.scanInstalledApps()
        }
    }
}
