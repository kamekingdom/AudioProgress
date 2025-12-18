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
    case exporting = "書き出し中"
    case playing = "再生中"
    case stopped = "停止"
    case error = "エラー"
}

struct ContentView: View {
    @StateObject private var controller: OverheadSpatialAudioController = OverheadSpatialAudioController()
    @State private var isImporterPresented: Bool = false
    @State private var status: PlaybackStatus = .ready
    @State private var errorMessage: String? = nil

    private let titleText: String = "Overhead Spatial Audio Demo"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"

    var body: some View {
        VStack(spacing: 16.0) {
            Text(titleText)
                .font(.largeTitle)
                .bold()
                .padding(.top, 24.0)
            Text(subtitleText)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            statusView
            controlButtons
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType.mpeg4Movie],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }

    private var statusView: some View {
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

    private var controlButtons: some View {
        HStack(spacing: 16.0) {
            Button(action: {
                errorMessage = nil
                isImporterPresented = true
            }) {
                Text("MP4を選択して再生")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(status == .exporting)

            Button(action: {
                controller.stopPlayback()
                status = .stopped
            }) {
                Text("停止")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
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
                await playSelectedFile(url: url)
            }
        case .failure(let error):
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    private func playSelectedFile(url: URL) async {
        let canAccess: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        status = .exporting
        do {
            try await controller.playSpatialAudio(from: url)
            status = .playing
            errorMessage = nil
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
