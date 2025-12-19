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
    @State private var selectedFileName: String? = nil
    @State private var selectedMode: SpatialMotionMode = .frontToBack

    private let titleText: String = "Overhead Spatial Audio Pad"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"
    private let heightY: Float = 1.2

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("デバッグ")) {
                    NavigationLink(destination: DebugSpatialAudioScreen()) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            Text("頭上平面オーディオパッド")
                                .font(.headline)
                            Text("再生進捗で空間移動するデバッグ用デモ")
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

struct DebugSpatialAudioScreen: View {
    @StateObject private var controller: OverheadSpatialAudioController = OverheadSpatialAudioController()
    @State private var isImporterPresented: Bool = false
    @State private var status: PlaybackStatus = .ready
    @State private var errorMessage: String? = nil
    @State private var selectedFileName: String? = nil
    @State private var selectedMode: SpatialMotionMode = .frontToBack

    private let titleText: String = "Overhead Spatial Audio Pad"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"
    private let heightY: Float = 1.2

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("デバッグ")) {
                    NavigationLink(destination: DebugSpatialAudioPanelView()) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            Text("頭上平面オーディオパッド")
                                .font(.headline)
                            Text("再生進捗で空間移動するデバッグ用デモ")
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

struct DebugSpatialAudioPanelView: View {
    @StateObject private var controller: OverheadSpatialAudioController = OverheadSpatialAudioController()
    @State private var isImporterPresented: Bool = false
    @State private var status: PlaybackStatus = .ready
    @State private var errorMessage: String? = nil
    @State private var selectedFileName: String? = nil
    @State private var selectedMode: SpatialMotionMode = .frontToBack

    private let titleText: String = "Overhead Spatial Audio Pad"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"
    private let heightY: Float = 1.2

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
            statusSection
            selectionSection
            modePickerSection
            controlsSection
            progressInfoSection
            Spacer()
        }
        .padding()
        .onAppear {
            do {
                try controller.prepare(heightY: heightY)
                controller.setMotionMode(selectedMode)
            } catch {
                status = .error
                errorMessage = error.localizedDescription
            }
        }
        .onReceive(controller.$isPlaying) { playing in
            if playing {
                status = .playing
            } else if status == .playing {
                status = .stopped
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType.mp3, UTType.audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileImporterResult(result: result)
        }
    }

    private var statusSection: some View {
        VStack(spacing: 8.0) {
            Text("ステータス: \(status.rawValue)")
                .font(.headline)
            if let message: String = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Text("Duration: \(controller.durationDescription)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var selectionSection: some View {
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

    private var modePickerSection: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text("モード")
                .font(.headline)
            Picker("モード", selection: $selectedMode) {
                ForEach(SpatialMotionMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10.0)
        .onChange(of: selectedMode) { newValue in
            controller.setMotionMode(newValue)
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 16.0) {
            Button(action: {
                togglePlaybackAction()
            }) {
                Text(status == .playing ? "停止" : "再生")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: {
                resetState()
            }) {
                Text("リセット")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var progressInfoSection: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text("進捗")
                .font(.headline)
            ProgressView(value: controller.progress, total: 1.0)
            Text(String(format: "%.1f%%", controller.progress * 100.0))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10.0)
    }

    private func togglePlaybackAction() {
        switch status {
        case .playing:
            controller.stop()
            status = .stopped
        case .fileSelected, .stopped:
            controller.playIfNeeded()
            status = controller.isReadyForPlayback ? .playing : status
        default:
            status = .error
            errorMessage = "先に音源ファイルを選択してください"
        }
    }

    private func resetState() {
        controller.reset()
        status = .ready
        selectedFileName = nil
        errorMessage = nil
        selectedMode = .frontToBack
        controller.setMotionMode(.frontToBack)
    }

    private func handleFileImporterResult(result: Result<[URL], Error>) {
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
