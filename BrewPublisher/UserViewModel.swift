//
//  UserViewModel.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//


import SwiftUI
import CryptoKit
import Combine
internal import UniformTypeIdentifiers

// MARK: - 全局用户状态管理
@MainActor
class UserViewModel: ObservableObject {
    @AppStorage("github_token") var token: String = ""
    @Published var currentUser: GitHubUser?
    @Published var isLoadingUser: Bool = false
    @Published var errorMessage: String?
    
    private let service = GitHubService()
    
    init() {
        if !token.isEmpty {
            Task { await verifyToken() }
        }
    }
    
    func verifyToken() async {
        guard !token.isEmpty else { return }
        isLoadingUser = true
        errorMessage = nil
        do {
            currentUser = try await service.fetchUser(token: token)
        } catch {
            errorMessage = error.localizedDescription
            currentUser = nil
        }
        isLoadingUser = false
    }
    
    func logout() {
        token = ""
        currentUser = nil
    }
}

// MARK: - 发布任务管理
@MainActor
class PublishViewModel: ObservableObject {
    enum BrewType: String, CaseIterable {
        case cask = "macOS App (Cask)"
        case formula = "CLI Tool (Formula)"
    }

    // 项目表单
    @Published var sourceRepoName: String = "" // 只填 repo 名，不带 user
    @Published var tapRepoName: String = "homebrew-tap" // 默认 tap
    @Published var appName: String = ""
    @Published var version: String = "1.0.0"
    @Published var description: String = ""
    @Published var homepage: String = ""
    
    // 状态
    @Published var selectedFileURL: URL?
    @Published var isProcessing: Bool = false
    @Published var logs: [String] = []
    
    @Published var brewType: BrewType = .cask
    private let metadataService = PackageMetadataService()
    private let service = GitHubService()
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        // 1. 我们查找任何符合 "文件" (fileURL) 类型的提供者，而不仅仅是 zip
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        
        // 2. 加载文件路径
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
            // 处理多线程回调
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                // 有时候 item 直接就是 URL
                if let url = item as? URL {
                    self.processDroppedFile(url)
                }
                return
            }
            self.processDroppedFile(url)
        }
        return true
    }
    
    // 内部辅助函数：验证并处理文件
    private func processDroppedFile(_ url: URL) {
        DispatchQueue.main.async {
            // 1. 基本检查
            if url.pathExtension.lowercased() == "zip" {
                self.selectedFileURL = url
                self.log("📦 已加载文件: \(url.lastPathComponent)")
                
                // 获取文件名（不带后缀），例如 "MyApp-1.0.zip" -> "MyApp-1.0"
                let filenameWithoutExt = url.deletingPathExtension().lastPathComponent
                
                // 赋值给 Source Repo (建议把空格替换为横杠，因为 GitHub Repo 不支持空格)
                self.sourceRepoName = filenameWithoutExt.replacingOccurrences(of: " ", with: "-")
                
                // 2. 开始解析元数据 (这是一个异步操作)
                Task {
                    self.log("🔍 正在分析 App 元数据...")
                    let metadata = await self.metadataService.extractMetadata(from: url)
                    
                    await MainActor.run {
                        // 3. 自动填入版本号
                        if let ver = metadata.version {
                            self.version = ver
                            self.log("✅ 识别到版本号: \(ver)")
                        } else {
                            self.log("⚠️ 未能识别版本号，请手动填写")
                        }
                        
                        // 4. 自动填入 App 名称 (如果还没填的话，或者想强制覆盖)
                        if let name = metadata.name {
                            // 简单的处理：转小写，去空格
                            let formattedName = name.lowercased().replacingOccurrences(of: " ", with: "")
                            
                            // 只有当用户还没填，或者填的是默认值时才覆盖，避免覆盖用户已修改的内容
                            if self.appName.isEmpty {
                                self.appName = formattedName
                                self.log("✅ 识别到应用名: \(formattedName)")
                            }
                        }
                        
                        // 5. 尝试根据 Bundle ID 推断 Repo 名称 (可选优化)
                        // 比如 com.google.chrome -> chrome
                        if let bundleId = metadata.bundleId, self.appName.isEmpty {
                            let lastPart = bundleId.components(separatedBy: ".").last ?? ""
                            if !lastPart.isEmpty {
                                self.appName = lastPart
                            }
                        }
                    }
                }
                
            } else {
                self.log("⚠️ 只能识别 .zip 文件，你拖入的是: .\(url.pathExtension)")
            }
        }
    }
    
    // 简单的文件名推断
    private func autoFillInfo(from url: URL) {
        // 假设文件名是 MyApp-1.0.zip 或 MyApp.zip
        let filename = url.deletingPathExtension().lastPathComponent
        // 简单的逻辑：如果文件名包含横杠或数字，尝试分割 (这里只是简单示例)
        let parts = filename.split(separator: "-")
        if let name = parts.first {
            self.appName = String(name).lowercased()
            self.sourceRepoName = String(name).lowercased()
        }
        
        self.logs.append("📦 已加载: \(url.lastPathComponent)")
    }
    
    // 执行发布
    func performPublish(user: GitHubUser, token: String) {
        guard let fileUrl = selectedFileURL else { return }
        isProcessing = true
        logs.removeAll()
        
        let fullSourceRepo = "\(user.login)/\(sourceRepoName)"
        let fullTapRepo = "\(user.login)/\(tapRepoName)"
        
        Task {
            do {
                log("👤 发布者: \(user.login)")
                
                // 1. SHA256
                log("🔄 计算 SHA256...")
                let data = try Data(contentsOf: fileUrl)
                let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                
                // 2. 获取或创建 Release (修复 422 问题)
                var release: GitHubRelease
                log("🔎 检查 Release: \(version)...")
                
                do {
                    // 尝试获取现有的
                    release = try await service.getReleaseByTag(token: token, repo: fullSourceRepo, tag: version)
                    log("⚠️ Release 已存在，将复用该 Release。")
                } catch {
                    // 如果获取失败（404），则创建新的
                    log("🆕 创建新 Release: \(version)...")
                    release = try await service.createRelease(token: token, repo: fullSourceRepo, tagName: version)
                }
                
                // 3. 检查是否有同名文件冲突 (修复覆盖上传问题)
                let filename = fileUrl.lastPathComponent
                if let existingAsset = release.assets.first(where: { $0.name == filename }) {
                    log("🗑 删除旧文件: \(filename) (ID: \(existingAsset.id))...")
                    try await service.deleteAsset(token: token, repo: fullSourceRepo, assetId: existingAsset.id)
                }
                
                // 4. Upload
                log("⬆️ 上传 Zip 文件...")
                let asset = try await service.uploadAsset(token: token, uploadUrl: release.uploadUrl, fileUrl: fileUrl)
                
                // 5. Generate Formula (保持不变)
                // 👇 修改核心逻辑：根据类型生成内容和路径
                let content: String
                let filePath: String
                
                if brewType == .formula {
                    // 模式 A: Formula (CLI)
                    let classPrefix = appName.prefix(1).uppercased() + appName.dropFirst() // Mytool
                    content = """
                    class \(classPrefix) < Formula
                      desc "\(description)"
                      homepage "\(homepage)"
                      url "\(asset.browserDownloadUrl)"
                      version "\(version)"
                      sha256 "\(hash)"

                      def install
                        bin.install "\(appName)"
                      end
                    end
                    """
                    filePath = "Formula/\(appName).rb"
                    
                } else {
                    // 模式 B: Cask (GUI App) -> 这是你现在需要的
                    // Cask 的 token 通常是全小写，用横杠连接
                    let caskToken = appName.lowercased().replacingOccurrences(of: " ", with: "-")
                    
                    content = """
                    cask "\(caskToken)" do
                      version "\(version)"
                      sha256 "\(hash)"

                      url "\(asset.browserDownloadUrl)"
                      name "\(appName)"
                      desc "\(description)"
                      homepage "\(homepage)"

                      auto_updates true
                      depends_on macos: ">= :monterey"

                      app "\(appName).app"
                    end
                    """
                    filePath = "Casks/\(caskToken).rb"
                }
                
                // 6. Update Repo
                log("📝 正在更新文件: \(filePath)...")
                
                // 调用修改后的 Service 方法
                try await service.updateFile(
                    token: token,
                    tapRepo: fullTapRepo,
                    path: filePath,
                    content: content,
                    message: "Update \(appName) to \(version) (\(brewType == .cask ? "Cask" : "Formula"))"
                )
                
                log("✅ 发布成功！")
                
                // 提示安装命令
                // 如果是 Cask，通常建议加 --cask 参数以防重名，虽然后来版本 brew 会自动识别
                if brewType == .cask {
                    log("👉 安装命令: brew install --cask \(fullTapRepo)/\(appName)")
                } else {
                    log("👉 安装命令: brew install \(fullTapRepo)/\(appName)")
                }

            } catch {
                log("❌ 错误: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    private func log(_ msg: String) { logs.append(msg) }
}
