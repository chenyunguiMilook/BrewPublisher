//
//  BrewPublisherApp.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//

import SwiftUI
import AppKit

@main
struct BrewPublisherApp: App {
    // 将 App 代理连接到 SwiftUI 生命周期
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 这里留空，因为我们不再通过 SwiftUI 管理 WindowGroup
        // 我们通过 Settings Scene 来防止 SwiftUI 报 "No Scene" 的警告（虽然 Settings 在 MenuBar 模式下很少用）
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate (核心控制器)
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var mainWindow: NSWindow? // 👈 保持窗口的强引用，确保单例
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // 设置图标 (这里用了一个系统图标，你可以换成自己的)
            button.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "BrewPublisher")
            button.action = #selector(toggleWindow)
        }
        
        // 2. 添加右键菜单 (提供退出选项，因为 Dock 没有图标了)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开主界面", action: #selector(openWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 BrewPublisher", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    // 点击状态栏图标的动作
    @objc func toggleWindow() {
        if let window = mainWindow, window.isVisible {
            // 如果窗口已显示，则关闭它 (Toggle 效果)
            window.close()
        } else {
            openWindow()
        }
    }
    
    @objc func openWindow() {
        // 防止重复创建：如果窗口已存在，直接前置
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建新窗口
        let contentView = ContentView() // 这里是你之前的主视图
        
        // 创建 NSWindow 实例
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "BrewPublisher"
        window.isReleasedWhenClosed = false // 👈 关键：关闭时只隐藏，不释放内存，方便下次快速显示
        window.contentView = NSHostingView(rootView: contentView)
        
        // 绑定到变量
        self.mainWindow = window
        
        // 显示并置顶
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
