//
//  GitHubRelease.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//


import Foundation

// MARK: - API Response Models
struct GitHubRelease: Codable {
    let id: Int
    let uploadUrl: String
    let htmlUrl: String
    let assets: [GitHubAsset] // 👈 新增：我们需要知道里面有哪些文件

    enum CodingKeys: String, CodingKey {
        case id, assets
        case uploadUrl = "upload_url"
        case htmlUrl = "html_url"
    }
}

struct GitHubAsset: Codable {
    let id: Int
    let name: String // 👈 新增：用于比对文件名
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case browserDownloadUrl = "browser_download_url"
    }
}

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let avatarUrl: String
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id, login, name
        case avatarUrl = "avatar_url"
    }
}

struct GitHubFileResponse: Codable {
    let content: GitHubFileContent?
    let sha: String? // 如果文件已存在，更新时需要这个 sha
}

struct GitHubFileContent: Codable {
    let sha: String?
}

// MARK: - App Errors
enum BrewError: Error, LocalizedError {
    case fileReadFailed
    case invalidURL
    case apiError(String)
    case noToken
    
    var errorDescription: String? {
        switch self {
        case .fileReadFailed: return "无法读取 Zip 文件"
        case .invalidURL: return "无效的 URL 地址"
        case .apiError(let msg): return "GitHub API 错误: \(msg)"
        case .noToken: return "请先配置 GitHub Token"
        }
    }
}
