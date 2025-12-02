//
//  GitHubService.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//


import Foundation

class GitHubService {
    private let session = URLSession.shared
    
    // 1. 创建 Release
    func createRelease(token: String, repo: String, tagName: String) async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(repo)/releases"
        guard let url = URL(string: urlString) else { throw BrewError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "tag_name": tagName,
            "name": tagName,
            "body": "Released via BrewPublisher",
            "draft": false,
            "prerelease": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
    
    // 2. 上传 Asset (Zip)
    func uploadAsset(token: String, uploadUrl: String, fileUrl: URL) async throws -> GitHubAsset {
        // uploadUrl 通常带有模板 "{?name,label}"，需要去掉
        let cleanUrlString = uploadUrl.components(separatedBy: "{").first!
        let fileName = fileUrl.lastPathComponent
        guard let url = URL(string: "\(cleanUrlString)?name=\(fileName)") else { throw BrewError.invalidURL }
        
        guard let fileData = try? Data(contentsOf: fileUrl) else { throw BrewError.fileReadFailed }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.httpBody = fileData
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        
        return try JSONDecoder().decode(GitHubAsset.self, from: data)
    }
    
    // 3. 更新或创建 Formula 文件
    func updateFile(token: String, tapRepo: String, path: String, content: String, message: String) async throws {
        // 注意：这里 urlString 变了，不再拼接 "Formula/"，而是直接用传入的 path
        // path 可能是 "Formula/myapp.rb" 也可能是 "Casks/myapp.rb"
        let urlString = "https://api.github.com/repos/\(tapRepo)/contents/\(path)"
        
        guard let url = URL(string: urlString) else { throw BrewError.invalidURL }
        
        // 3.1 检查文件是否存在以获取 SHA (如果存在)
        var existingSha: String? = nil
        
        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, response) = try? await session.data(for: getRequest),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            let fileInfo = try? JSONDecoder().decode(GitHubFileResponse.self, from: data)
            existingSha = fileInfo?.sha
        }
        
        // 3.2 提交文件 (Base64 编码)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let contentBase64 = content.data(using: .utf8)?.base64EncodedString() ?? ""
        
        var body: [String: Any] = [
            "message": message, // message 也参数化
            "content": contentBase64
        ]
        
        if let sha = existingSha {
            body["sha"] = sha
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }
    
    // Helper: 验证响应
    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        if !(200...299).contains(httpResponse.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BrewError.apiError("Status \(httpResponse.statusCode): \(msg)")
        }
    }
    
    func fetchUser(token: String) async throws -> GitHubUser {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BrewError.apiError("Token 无效或网络错误")
        }
        
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }
    
    // 1. 根据 Tag 获取 Release (用于检测是否存在)
    func getReleaseByTag(token: String, repo: String, tag: String) async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(repo)/releases/tags/\(tag)"
        guard let url = URL(string: urlString) else { throw BrewError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            throw BrewError.apiError("Release not found") // 这是一个预期的错误，不用慌
        }
        
        try validate(response: response, data: data)
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
    
    // 2. 删除 Asset (用于覆盖上传)
    func deleteAsset(token: String, repo: String, assetId: Int) async throws {
        let urlString = "https://api.github.com/repos/\(repo)/releases/assets/\(assetId)"
        guard let url = URL(string: urlString) else { throw BrewError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }
}
