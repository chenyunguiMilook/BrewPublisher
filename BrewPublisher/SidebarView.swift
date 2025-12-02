//
//  SidebarView.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//

import SwiftUI
import Combine

// MARK: - 侧边栏：用户管理
struct SidebarView: View {
    @ObservedObject var userVM: UserViewModel
    @StateObject private var launchAtLogin = LaunchAtLogin.shared // 👈 新增
    @State private var tempToken: String = ""
    @Environment(\.openURL) var openURL // 用于跳转浏览器
    
    var body: some View {
        ZStack {
            // 背景点击收起键盘（可选）
            Color(NSColor.controlBackgroundColor)
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            
            if let user = userVM.currentUser {
                // MARK: - 已登录状态 (顶部对齐)
                VStack(spacing: 20) {
                    VStack(spacing: 15) {
                        AsyncImage(url: URL(string: user.avatarUrl)) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.2))
                                .overlay(ProgressView())
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.top, 40)
                        
                        VStack(spacing: 4) {
                            Text(user.name ?? user.login)
                                .font(.title3)
                                .fontWeight(.medium)
                            Text("@\(user.login)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider().padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("开机自动启动", isOn: $launchAtLogin.isEnabled)
                            .toggleStyle(.switch)
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: { userVM.logout() }) {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .padding(.bottom, 20)
                }
            } else {
                // MARK: - 未登录状态 (垂直居中)
                ScrollView {
                    VStack(alignment: .center, spacing: 25) {
                        
                        // 标题区
                        VStack(spacing: 8) {
                            Image(systemName: "lock.laptopcomputer")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                                .padding(.bottom, 5)
                            
                            Text("GitHub 授权")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("发布应用需要访问 Release 权限")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 表单区
                        VStack(alignment: .leading, spacing: 15) {
                            
                            // 跳转按钮
                            Button(action: {
                                let urlString = "https://github.com/settings/tokens/new?scopes=repo,read:user&description=BrewPublisher"
                                if let url = URL(string: urlString) { openURL(url) }
                            }) {
                                HStack {
                                    Image(systemName: "safari")
                                    Text("去 GitHub 创建 Token")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.bordered) // 更像一个功能按钮
                            .controlSize(.small)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Personal Access Token")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                SecureField("ghp_xxxx...", text: $tempToken)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        // 允许按回车提交
                                        if !tempToken.isEmpty {
                                            userVM.token = tempToken
                                            Task { await userVM.verifyToken() }
                                        }
                                    }
                            }
                            
                            // 错误提示区
                            if let err = userVM.errorMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(translateError(err)) // 翻译一下错误
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                userVM.token = tempToken
                                Task { await userVM.verifyToken() }
                            }) {
                                HStack {
                                    if userVM.isLoadingUser {
                                        ProgressView().controlSize(.small)
                                    }
                                    Text("验证并登录")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(tempToken.isEmpty || userVM.isLoadingUser)
                        }
                        .frame(maxWidth: 280) // 限制宽度，防止在大屏幕上太宽
                    }
                    .padding()
                    .frame(minHeight: 400) // 确保有足够高度进行居中计算
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
    }
    
    // 简单的错误翻译助手
    func translateError(_ error: String) -> String {
        if error.contains("Operation not permitted") {
            return "网络被拦截：请在 Xcode 中开启 'Outgoing Connections (Client)' 权限。"
        }
        if error.contains("401") {
            return "Token 无效或过期，请检查。"
        }
        return error
    }
}
