//
//  LaunchAtLogin.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//


import Foundation
import ServiceManagement
import Combine

class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()
    
    @Published var isEnabled: Bool {
        didSet {
            updateStatus()
        }
    }
    
    init() {
        // 初始化时检查当前状态
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func updateStatus() {
        let service = SMAppService.mainApp
        
        do {
            if isEnabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            print("更改开机启动状态失败: \(error)")
        }
    }
}
