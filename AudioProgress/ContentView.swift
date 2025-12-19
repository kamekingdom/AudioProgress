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
    @StateObject private var controller: OverheadSpatialAudioController = OverheadSpatialAudioController()
    @State private var isImporterPresented: Bool = false
    @State private var status: PlaybackStatus = .ready
    @State private var errorMessage: String? = nil
    @State private var displayPoint: CGPoint? = nil

    private let titleText: String = "Overhead Spatial Audio Pad"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"
    private let heightY: Float = 1.2
    private let rangeMeters: Float = 1.5

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
            statusSectionView
            controlButtonsView
            SpatialPadView(
                heightLabel: "Overhead plane y=\(heightY)m",
                rangeMeters: rangeMeters,
                currentPoint: displayPoint
            ) { x, z, point in
                guard status == .fileSelected || status == .playing else {
                    return
                }
                displayPoint = point
                controller.setSourcePosition(x: x, z: z)
                controller.playIfNeeded()
                if status == .fileSelected {
                    status = .playing
                }
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
            processFileImport(result: result)
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

    private var controlButtonsView: some View {
        HStack(spacing: 16.0) {
            Button(action: {
                errorMessage = nil
                status = .selecting
                isImporterPresented = true
            }) {
                Text("音源ファイルを選択")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: {
                controller.stop()
                status = .stopped
            }) {
                Text("停止")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func processFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url: URL = urls.first else {
                status = .error
                errorMessage = "ファイルが選択されませんでした"
                return
            }
            Task {
                await loadSelectedFile(url: url)
            }
        case .failure(let error):
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    private func loadSelectedFile(url: URL) async {
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
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
