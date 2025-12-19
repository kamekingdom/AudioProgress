// Author: kamekingdom (2025-12-18)
//
//  OverheadSpatialAudioController.swift
//  AudioProgress
//
//  Created by ChatGPT on 2025/12/18.

import Foundation
import AVFoundation
import UIKit

enum SpatialAudioError: Error {
    case notPrepared
    case assetNotReadable
    case exportSessionUnavailable
    case exportFailed(message: String)
    case audioSessionUnavailable
    case engineStartFailed
    case fileUnavailable
    case scheduleFailed
    case invalidDuration
}

enum SpatialMotionMode: String, CaseIterable, Identifiable {
    case frontToBack
    case leftToRight
    case bottomToTop
    case overheadOrbit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frontToBack:
            return "Front → Back"
        case .leftToRight:
            return "Left → Right"
        case .bottomToTop:
            return "Bottom → Top"
        case .overheadOrbit:
            return "Overhead Orbit"
        }
    }
}

final class OverheadSpatialAudioController: ObservableObject {
    private let audioEngine: AVAudioEngine
    private let environmentNode: AVAudioEnvironmentNode
    private let playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var heightY: Float = 1.2
    private var sourcePosition: AVAudio3DPoint = AVAudio3DPoint(x: 0.0, y: 1.2, z: 0.0)
    private var isPrepared: Bool = false
    private var displayLink: CADisplayLink?
    private var durationSecInternal: Double = 0.0
    private var motionMode: SpatialMotionMode = .frontToBack
    private let frontZ: Float = -1.0
    private let backZ: Float = 1.0
    private let leftX: Float = -1.0
    private let rightX: Float = 1.0
    private let bottomY: Float = 0.0
    private let topY: Float = 1.2
    private let orbitRadius: Float = 1.0

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var durationSec: Double = 0.0

    var isReadyForPlayback: Bool {
        return audioFile != nil
    }

    var durationDescription: String {
        guard durationSec > 0 else {
            return "--"
        }
        return String(format: "%.2f s", durationSec)
    }

    init() {
        let engine: AVAudioEngine = AVAudioEngine()
        audioEngine = engine

        let environment: AVAudioEnvironmentNode = AVAudioEnvironmentNode()
        environment.listenerPosition = AVAudio3DPoint(x: 0.0, y: 0.0, z: 0.0)
        environmentNode = environment

        let player: AVAudioPlayerNode = AVAudioPlayerNode()
        player.renderingAlgorithm = .HRTF
        playerNode = player
    }

    func prepare(heightY: Float) throws {
        stop()
        self.heightY = heightY
        sourcePosition = AVAudio3DPoint(x: 0.0, y: heightY, z: 0.0)
        try configureAudioSession()
        attachNodesIfNeeded()
        isPrepared = true
    }

    func loadAudio(from url: URL) async throws {
        guard isPrepared else {
            throw SpatialAudioError.notPrepared
        }
        stop()
        let m4aURL: URL = try await exportAudio(from: url)
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: m4aURL)
        } catch {
            throw SpatialAudioError.fileUnavailable
        }
        audioFile = file
        durationSecInternal = Double(file.length) / file.processingFormat.sampleRate
        guard durationSecInternal > 0 else {
            throw SpatialAudioError.invalidDuration
        }
        durationSec = durationSecInternal
        progress = 0.0
        try configureEngineForAudioFile(file)
    }

    func playIfNeeded() {
        guard let file: AVAudioFile = audioFile else {
            return
        }
        if isPlaying {
            return
        }
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                return
            }
        }
        playerNode.stop()
        let completionHandler: () -> Void = { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.progress = 0.0
                self?.stopMotionUpdates()
            }
        }
        playerNode.scheduleFile(file, at: nil, completionHandler: completionHandler)
        playerNode.play()
        isPlaying = true
        startMotionUpdates()
        updateProgressAndPosition()
    }

    func setSourcePosition(x: Float, z: Float) {
        sourcePosition = AVAudio3DPoint(x: x, y: heightY, z: z)
        playerNode.position = sourcePosition
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        isPlaying = false
        progress = 0.0
        stopMotionUpdates()
    }

    func reset() {
        stop()
        audioFile = nil
        durationSecInternal = 0.0
        durationSec = 0.0
        progress = 0.0
    }

    func setMotionMode(_ mode: SpatialMotionMode) {
        motionMode = mode
    }

    // MARK: - Private

    private func configureAudioSession() throws {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true, options: [])
        } catch {
            throw SpatialAudioError.audioSessionUnavailable
        }
    }

    private func attachNodesIfNeeded() {
        if !audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.attach(playerNode)
        }
        if !audioEngine.attachedNodes.contains(environmentNode) {
            audioEngine.attach(environmentNode)
        }
    }

    private func configureEngineForAudioFile(_ audioFile: AVAudioFile) throws {
        audioEngine.stop()
        audioEngine.reset()
        attachNodesIfNeeded()

        let format: AVAudioFormat = audioFile.processingFormat
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(environmentNode)
        audioEngine.connect(playerNode, to: environmentNode, format: format)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: nil)

        environmentNode.listenerPosition = AVAudio3DPoint(x: 0.0, y: 0.0, z: 0.0)
        playerNode.renderingAlgorithm = .HRTF
        playerNode.position = sourcePosition

        do {
            try audioEngine.start()
        } catch {
            throw SpatialAudioError.engineStartFailed
        }
    }

    private func exportAudio(from sourceURL: URL) async throws -> URL {
        let asset: AVAsset = AVAsset(url: sourceURL)
        guard let exportSession: AVAssetExportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SpatialAudioError.exportSessionUnavailable
        }
        let outputURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("exported-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed, .cancelled:
                    let message: String = exportSession.error?.localizedDescription ?? "不明なエラー"
                    continuation.resume(throwing: SpatialAudioError.exportFailed(message: message))
                default:
                    continuation.resume(throwing: SpatialAudioError.assetNotReadable)
                }
            }
        }
    }

    private func startMotionUpdates() {
        stopMotionUpdates()
        let link: CADisplayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopMotionUpdates() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLink() {
        updateProgressAndPosition()
    }

    private func updateProgressAndPosition() {
        guard isPlaying else {
            return
        }
        guard durationSecInternal > 0.0 else {
            progress = 0.0
            return
        }
        guard let currentSec: Double = currentPlaybackTime() else {
            return
        }
        let clampedProgress: Double = min(max(currentSec / durationSecInternal, 0.0), 1.0)
        progress = clampedProgress
        let position: AVAudio3DPoint = position(for: Float(clampedProgress))
        sourcePosition = position
        playerNode.position = position
    }

    private func currentPlaybackTime() -> Double? {
        guard let nodeTime: AVAudioTime = playerNode.lastRenderTime,
              let playerTime: AVAudioTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        let sampleTime: Double = Double(playerTime.sampleTime)
        let rate: Double = playerTime.sampleRate
        guard rate > 0 else {
            return nil
        }
        return sampleTime / rate
    }

    private func position(for progress: Float) -> AVAudio3DPoint {
        switch motionMode {
        case .frontToBack:
            let zValue: Float = frontZ + (backZ - frontZ) * progress
            return AVAudio3DPoint(x: 0.0, y: heightY, z: zValue)
        case .leftToRight:
            let xValue: Float = leftX + (rightX - leftX) * progress
            return AVAudio3DPoint(x: xValue, y: heightY, z: 0.0)
        case .bottomToTop:
            let yValue: Float = bottomY + (topY - bottomY) * progress
            return AVAudio3DPoint(x: 0.0, y: yValue, z: 0.0)
        case .overheadOrbit:
            let theta: Float = Float(2.0 * Double.pi) * progress
            let xValue: Float = orbitRadius * cos(theta)
            let zValue: Float = orbitRadius * sin(theta)
            return AVAudio3DPoint(x: xValue, y: heightY, z: zValue)
        }
    }
}
