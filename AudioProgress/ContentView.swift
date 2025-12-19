// Author: kamekingdom (2025-12-18)
//
//  ContentView.swift
//  AudioProgress
//
//  Created by 中村裕大 on 2025/12/18.

import SwiftUI
import UniformTypeIdentifiers

enum PlaybackStatus: String {
    case ready = "準備完了"
    case selecting = "ファイル選択"
    case exporting = "変換中"
    case fileSelected = "ファイル選択済み"
    case playing = "再生中"
    case stopped = "停止"
    case error = "エラー"
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("デバッグ")) {
                    NavigationLink(destination: DebugSpatialAudioView()) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            Text("頭上平面オーディオパッド")
                                .font(.headline)
                            Text("音源位置タッチ＋空間オーディオ（デバッグ用）")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("メニュー")
        }
    }
}

struct DebugSpatialAudioView: View {
    @StateObject private var controller: OverheadSpatialAudioController = OverheadSpatialAudioController()
    @State private var isImporterPresented: Bool = false
    @State private var status: PlaybackStatus = .ready
    @State private var errorMessage: String? = nil
    @State private var displayPoint: CGPoint? = nil
    @State private var selectedFileName: String? = nil

    private let titleText: String = "Overhead Spatial Audio Pad"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"
    private let heightY: Float = 1.2
    private let rangeMeters: Float = 1.5

    var body: some View {
        VStack(spacing: 16.0) {
            Text(titleText)
                .font(.title)
                .bold()
                .padding(.top, 16.0)
            Text(subtitleText)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            statusSectionView
            selectionSectionView
            controlsSectionView
            SpatialPadView(
                heightLabel: "Overhead plane y=\(heightY)m",
                rangeMeters: rangeMeters,
                currentPoint: displayPoint
            ) { x, z, point in
                guard status == .fileSelected || status == .playing || status == .stopped else {
                    return
                }
                displayPoint = point
                controller.setSourcePosition(x: x, z: z)
                controller.playIfNeeded()
                status = .playing
            }
            Spacer()
        }
        .padding()
        .onAppear {
            do {
                try controller.prepare(heightY: heightY)
            } catch {
                status = .error
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType.mp3, UTType.audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }

    private var statusSectionView: some View {
        VStack(spacing: 8.0) {
            Text("ステータス: \(status.rawValue)")
                .font(.headline)
            if let message: String = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private var selectionSectionView: some View {
        VStack(spacing: 8.0) {
            Button(action: {
                errorMessage = nil
                status = .selecting
                isImporterPresented = true
            }) {
                Text("音源ファイルを選択")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Text("選択中のファイル: ")
                    .font(.subheadline)
                Text(selectedFileName ?? "未選択")
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8.0)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10.0)
    }

    private var controlsSectionView: some View {
        HStack(spacing: 16.0) {
            Button(action: {
                togglePlayback()
            }) {
                Text(status == .playing ? "停止" : "再生")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: {
                resetAll()
            }) {
                Text("リセット")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func togglePlayback() {
        switch status {
        case .playing:
            controller.stop()
            status = .stopped
        case .fileSelected, .stopped:
            controller.playIfNeeded()
            status = .playing
        default:
            status = .error
            errorMessage = "先に音源ファイルを選択してください"
        }
    }

    private func resetAll() {
        controller.reset()
        status = .ready
        displayPoint = nil
        selectedFileName = nil
        errorMessage = nil
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url: URL = urls.first else {
                status = .error
                errorMessage = "ファイルが選択されませんでした"
                return
            }
            Task {
                await performLoadSelectedFile(url: url)
            }
        case .failure(let error):
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    private func performLoadSelectedFile(url: URL) async {
        let canAccess: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        status = .exporting
        do {
            try await controller.loadAudio(from: url)
            status = .fileSelected
            displayPoint = nil
            errorMessage = nil
            selectedFileName = url.lastPathComponent
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
