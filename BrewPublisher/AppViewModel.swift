//
//  AppViewModel.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//


import SwiftUI
import CryptoKit
import Combine

@MainActor
class AppViewModel: ObservableObject {
    // UI State
    @Published var token: String = "" // 建议使用 @AppStorage 或 Keychain
    @Published var sourceRepo: String = "user/repo"
    @Published var tapRepo: String = "user/homebrew-tap"
    @Published var version: String = "1.0.0"
    @Published var appName: String = "myapp"
    @Published var description: String = "My awesome app"
    @Published var homepage: String = "https://example.com"
    
    @Published var selectedFileURL: URL?
    @Published var isProcessing: Bool = false
    @Published var logs: [String] = []
    
    private let service = GitHubService()
    
    // 拖拽处理
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.zip-archive") }) {
            provider.loadItem(forTypeIdentifier: "public.zip-archive", options: nil) { (item, error) in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self.selectedFileURL = url
                        self.log("📦 已加载文件: \(url.lastPathComponent)")
                    }
                }
            }
            return true
        }
        return false
    }
    
    // 核心发布流程
    func startPublish() {
        guard !token.isEmpty else {
            log("❌ 错误: 请填写 GitHub Token")
            return
        }
        guard let fileUrl = selectedFileURL else {
            log("❌ 错误: 请先拖入 Zip 文件")
            return
        }
        
        isProcessing = true
        logs.removeAll()
        
        Task {
            do {
                // 1. 计算 SHA256
                log("🔄 正在计算 SHA256...")
                let sha256 = try calculateSHA256(for: fileUrl)
                log("✅ SHA256: \(sha256.prefix(8))...")
                
                // 2. 创建 Release
                log("🚀 正在 GitHub 创建 Release: \(version)...")
                let release = try await service.createRelease(token: token, repo: sourceRepo, tagName: version)
                
                // 3. 上传 Zip
                log("⬆️ 正在上传 Asset...")
                let asset = try await service.uploadAsset(token: token, uploadUrl: release.uploadUrl, fileUrl: fileUrl)
                
                // 4. 生成 Formula 内容
                let formulaContent = generateFormula(
                    url: asset.browserDownloadUrl,
                    sha256: sha256
                )
                
                // 5. 提交 Formula
                log("📝 正在更新 Homebrew Tap...")
                try await service.updateFormula(token: token, tapRepo: tapRepo, formulaName: appName, content: formulaContent)
                
                log("🎉 发布成功！")
                log("你可以运行: brew install \(tapRepo.split(separator: "/").last ?? "")/\(appName)")
                
            } catch {
                log("❌ 失败: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    // SHA256 计算
    private func calculateSHA256(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // 生成 Formula 模板
    private func generateFormula(url: String, sha256: String) -> String {
        // 首字母大写类名
        let className = appName.prefix(1).uppercased() + appName.dropFirst()
        
        return """
        class \(className) < Formula
          desc "\(description)"
          homepage "\(homepage)"
          url "\(url)"
          version "\(version)"
          sha256 "\(sha256)"

          def install
            bin.install "\(appName)" 
          end
        end
        """
    }
    
    private func log(_ message: String) {
        logs.append(message)
    }
}
