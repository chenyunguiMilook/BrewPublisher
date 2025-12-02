//
//  AppMetadata.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//


import Foundation

struct AppMetadata {
    let version: String?
    let name: String?
    let bundleId: String?
}

class PackageMetadataService {
    
    // 异步读取 Zip 中的 Info.plist
    func extractMetadata(from zipURL: URL) async -> AppMetadata {
        // 1. 我们需要找到 Zip 里 Info.plist 的具体路径
        // 通常是 "AppName.app/Contents/Info.plist"
        guard let plistData = await runUnzipCommand(zipURL: zipURL, pattern: "*.app/Contents/Info.plist") else {
            print("⚠️ 未能在 Zip 中找到 Info.plist")
            return AppMetadata(version: nil, name: nil, bundleId: nil)
        }
        
        // 2. 解析 Plist 数据
        do {
            if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                
                // 读取版本号 (CFBundleShortVersionString)
                let version = plist["CFBundleShortVersionString"] as? String
                
                // 读取 App 名称 (CFBundleName)
                let name = plist["CFBundleName"] as? String
                
                // 读取 Bundle ID
                let bundleId = plist["CFBundleIdentifier"] as? String
                
                return AppMetadata(version: version, name: name, bundleId: bundleId)
            }
        } catch {
            print("❌ 解析 Info.plist 失败: \(error)")
        }
        
        return AppMetadata(version: nil, name: nil, bundleId: nil)
    }
    
    // 私有辅助方法：运行 /usr/bin/unzip -p 提取文件内容到内存
    private func runUnzipCommand(zipURL: URL, pattern: String) async -> Data? {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            // 参数说明：
            // -p : extract files to pipe (standard output) -> 直接输出内容，不写磁盘
            // pattern : 匹配文件名的模式
            task.arguments = ["-p", zipURL.path, pattern]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            // 忽略错误输出，避免控制台太乱
            task.standardError = Pipe()
            
            do {
                try task.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                if !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: nil)
                }
            } catch {
                print("❌ 无法运行 unzip 命令: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
}