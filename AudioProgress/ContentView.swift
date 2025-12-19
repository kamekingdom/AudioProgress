// Author: kamekingdom (2025-12-18)
//
//  ContentView.swift
//  AudioProgress
//
//  Created by 中村裕大 on 2025/12/18.

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

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
    @State private var selectedFileName: String? = nil
    @State private var selectedMode: SpatialMotionMode = .frontToBack

    private let titleText: String = "頭上平面オーディオパッド"
    private let subtitleText: String = "実機＋AirPodsなどのヘッドホンでテスト推奨（シミュレータでは空間感が評価しにくいです）"
    private let heightY: Float = 1.2
    private let rangeMeters: Float = 1.5
    private let heightRangeMeters: Float = 1.5

    var body: some View {
        ScrollView {
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
                positionVisualizationSection
                Spacer()
            }
            .padding()
        }
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

            VStack(alignment: .leading, spacing: 4.0) {
                Text("選択中のファイル")
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
            if controller.durationSec > 0.0 {
                let currentSec: Double = controller.durationSec * controller.progress
                Text(String(format: "current %.2fs / %.2fs", currentSec, controller.durationSec))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10.0)
    }

    private var positionVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            Text("現在位置の可視化")
                .font(.headline)
            SpatialPositionVisualizer(currentPosition: controller.currentPosition, rangeMeters: rangeMeters, heightRangeMeters: heightRangeMeters)
                .frame(maxWidth: .infinity)
        }
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

struct SpatialPositionVisualizer: View {
    let currentPosition: AVAudio3DPoint
    let rangeMeters: Float
    let heightRangeMeters: Float

    var body: some View {
        VStack(spacing: 12.0) {
            OverheadPositionView(currentPosition: currentPosition, rangeMeters: rangeMeters)
                .frame(height: 220.0)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12.0)
            SideHeightView(currentPosition: currentPosition, heightRangeMeters: heightRangeMeters)
                .frame(height: 140.0)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12.0)
        }
    }
}

struct OverheadPositionView: View {
    let currentPosition: AVAudio3DPoint
    let rangeMeters: Float

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, canvasSize in
                let center: CGPoint = CGPoint(x: canvasSize.width / 2.0, y: canvasSize.height / 2.0)
                let radius: CGFloat = min(canvasSize.width, canvasSize.height) / 2.0 - 12.0
                drawGrid(in: canvasSize, radius: radius, center: center, context: &context)
                drawHead(center: center, context: &context)
                drawLabels(radius: radius, center: center, context: &context)
                let displayPoint: CGPoint = mapPoint(position: currentPosition, radius: radius, center: center)
                drawSourcePoint(displayPoint, context: &context)
            }
            VStack {
                HStack {
                    Text("頭上からの視点")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text("y=\(String(format: "%.2f", currentPosition.y))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(8.0)
        }
    }

    private func mapPoint(position: AVAudio3DPoint, radius: CGFloat, center: CGPoint) -> CGPoint {
        let metersPerRadius: CGFloat = CGFloat(rangeMeters)
        let xRatio: CGFloat = CGFloat(position.x) / metersPerRadius
        let zRatio: CGFloat = CGFloat(position.z) / metersPerRadius
        let x: CGFloat = center.x + xRatio * radius
        let y: CGFloat = center.y + zRatio * radius
        return CGPoint(x: x, y: y)
    }

    private func drawGrid(in size: CGSize, radius: CGFloat, center: CGPoint, context: inout GraphicsContext) {
        let circlePath: Path = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0))
        context.stroke(circlePath, with: .color(.gray.opacity(0.25)), lineWidth: 1.0)

        var axesPath: Path = Path()
        axesPath.move(to: CGPoint(x: center.x, y: center.y - radius))
        axesPath.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        axesPath.move(to: CGPoint(x: center.x - radius, y: center.y))
        axesPath.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.stroke(axesPath, with: .color(.gray.opacity(0.4)), lineWidth: 1.0)
    }

    private func drawHead(center: CGPoint, context: inout GraphicsContext) {
        let headRadius: CGFloat = 12.0
        let headRect: CGRect = CGRect(x: center.x - headRadius, y: center.y - headRadius, width: headRadius * 2.0, height: headRadius * 2.0)
        let headPath: Path = Path(ellipseIn: headRect)
        context.fill(headPath, with: .color(.blue.opacity(0.6)))
    }

    private func drawLabels(radius: CGFloat, center: CGPoint, context: inout GraphicsContext) {
        let offset: CGFloat = radius + 12.0
        context.draw(Text("Front"), at: CGPoint(x: center.x, y: center.y - offset))
        context.draw(Text("Back"), at: CGPoint(x: center.x, y: center.y + offset))
        context.draw(Text("Left"), at: CGPoint(x: center.x - offset, y: center.y))
        context.draw(Text("Right"), at: CGPoint(x: center.x + offset, y: center.y))
    }

    private func drawSourcePoint(_ point: CGPoint, context: inout GraphicsContext) {
        let radius: CGFloat = 8.0
        let rect: CGRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2.0, height: radius * 2.0)
        let path: Path = Path(ellipseIn: rect)
        context.fill(path, with: .color(.red))
    }
}

struct SideHeightView: View {
    let currentPosition: AVAudio3DPoint
    let heightRangeMeters: Float

    var body: some View {
        GeometryReader { _ in
            Canvas { context, canvasSize in
                let groundY: CGFloat = canvasSize.height - 16.0
                let topY: CGFloat = 16.0
                let heightSpan: CGFloat = max(0.1, groundY - topY)
                let metersPerPoint: CGFloat = CGFloat(heightRangeMeters) / heightSpan
                let yValue: CGFloat = groundY - CGFloat(currentPosition.y) / metersPerPoint

                var axisPath: Path = Path()
                axisPath.move(to: CGPoint(x: canvasSize.width / 2.0, y: groundY))
                axisPath.addLine(to: CGPoint(x: canvasSize.width / 2.0, y: topY))
                context.stroke(axisPath, with: .color(.gray.opacity(0.5)), lineWidth: 1.0)

                let headRadius: CGFloat = 10.0
                let headRect: CGRect = CGRect(x: canvasSize.width / 2.0 - headRadius, y: groundY - headRadius * 2.0, width: headRadius * 2.0, height: headRadius * 2.0)
                let headPath: Path = Path(ellipseIn: headRect)
                context.fill(headPath, with: .color(.blue.opacity(0.6)))

                let sourceRadius: CGFloat = 8.0
                let sourceRect: CGRect = CGRect(x: canvasSize.width / 2.0 + 30.0, y: yValue - sourceRadius, width: sourceRadius * 2.0, height: sourceRadius * 2.0)
                let sourcePath: Path = Path(ellipseIn: sourceRect)
                context.fill(sourcePath, with: .color(.red))

                let linePathRect: CGRect = CGRect(x: canvasSize.width / 2.0, y: yValue, width: 30.0, height: 0.5)
                var linePath: Path = Path()
                linePath.addRect(linePathRect)
                context.fill(linePath, with: .color(.red.opacity(0.6)))
            }
            VStack {
                HStack {
                    Text("横からの高さ視点")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text("y=\(String(format: "%.2f", currentPosition.y))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(8.0)
        }
    }
}

#Preview {
    ContentView()
}
