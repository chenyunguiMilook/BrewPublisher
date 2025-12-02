//
//  ProjectPanelView.swift
//  BrewPublisher
//
//  Created by chenyungui on 2025/12/2.
//

import SwiftUI
import Combine
internal import UniformTypeIdentifiers

// MARK: - 主面板：拖拽与发布
struct ProjectPanelView: View {
    @ObservedObject var publishVM: PublishViewModel
    let user: GitHubUser
    let token: String
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: 1. 顶部：拖拽区域 (保持不变)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(publishVM.isProcessing ? .gray : .blue.opacity(0.5))
                    .background(Color(NSColor.controlBackgroundColor))
                    .padding(16)
                
                if let url = publishVM.selectedFileURL {
                    HStack(spacing: 24) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 56))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已就绪")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(url.lastPathComponent)
                                .font(.title2)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button(action: { publishVM.selectedFileURL = nil }) {
                                Label("更换文件", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.link)
                            .disabled(publishVM.isProcessing)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary)
                        Text("将 Archive (.zip) 拖放到此处")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 160)
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in // 👈 关键点：使用 UTType.fileURL
                publishVM.handleDrop(providers: providers)
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // MARK: 2. 底部：表单与操作区 (修改重点)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 分组 1: 仓库设置
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "GitHub Repositories")
                        
                        // Source Repo
                        HStack {
                            LabelText("Source Repo")
                            Text("\(user.login) /")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                            TextField("my-app", text: $publishVM.sourceRepoName)
                                .textFieldStyle(.roundedBorder) // 👈 关键修改
                        }
                        
                        // Tap Repo
                        HStack {
                            LabelText("Tap Repo")
                            Text("\(user.login) /")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                            TextField("homebrew-tap", text: $publishVM.tapRepoName)
                                .textFieldStyle(.roundedBorder) // 👈 关键修改
                        }
                    }
                    
                    Divider()
                    
                    // 分组 2: Release 信息
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Release Details")
                        
                        // 使用提取的子视图来简化代码
                        InputRow(label: "Formula Name", placeholder: "e.g. mytool", text: $publishVM.appName)
                        InputRow(label: "Version Tag", placeholder: "e.g. 1.0.0", text: $publishVM.version)
                        InputRow(label: "Homepage", placeholder: "https://example.com", text: $publishVM.homepage)
                        InputRow(label: "Description", placeholder: "Brief description of your app...", text: $publishVM.description)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // MARK: 3. 底部固定区域：日志 + 按钮 (保持不变，微调了onChange)
            VStack(spacing: 12) {
                if !publishVM.logs.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(publishVM.logs, id: \.self) { log in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(log.contains("❌") ? Color.red : (log.contains("✅") ? Color.green : Color.primary))
                                            .frame(width: 6, height: 6)
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled) // 👈 关键修改：允许选择和复制文字
                            .id("bottom")
                        }
                        .frame(height: 100)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        .onChange(of: publishVM.logs.count) { _, _ in
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                }
                
                HStack {
                    if publishVM.isProcessing {
                        ProgressView().controlSize(.small).padding(.trailing, 5)
                        Text("Processing...").foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { publishVM.performPublish(user: user, token: token) }) {
                        Text(publishVM.isProcessing ? "发布中..." : "Publish Release & Update Tap")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(publishVM.isProcessing || publishVM.selectedFileURL == nil || publishVM.sourceRepoName.isEmpty)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - 辅助组件 (让主代码更干净)

// 1. 统一的标签样式
struct LabelText: View {
    let text: String
    init(_ text: String) { self.text = text }
    
    var body: some View {
        Text(text)
            .frame(width: 100, alignment: .trailing) // 固定宽度确保对齐
            .foregroundColor(.secondary)
            .padding(.trailing, 5)
    }
}

// 2. 统一的输入行组件
struct InputRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            LabelText(label)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder) // 统一应用圆角边框样式
        }
    }
}

// 3. 分组标题
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.bottom, 5)
    }
}
