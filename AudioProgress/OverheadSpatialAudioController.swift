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
}

final class OverheadSpatialAudioController: ObservableObject {
    private let audioEngine: AVAudioEngine
    private let environmentNode: AVAudioEnvironmentNode
    private let playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var heightY: Float = 1.2
    private var sourcePosition: AVAudio3DPoint = AVAudio3DPoint(x: 0.0, y: 1.2, z: 0.0)
    private var isPrepared: Bool = false
    private var isPlaying: Bool = false

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
        try configureEngineForAudioFile(file)
    }

    func playIfNeeded() {
        guard let file: AVAudioFile = audioFile else {
            return
        }
        if isPlaying {
            return
        }
        playerNode.stop()
        let completionHandler: () -> Void = { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        }
        playerNode.scheduleFile(file, at: nil, completionHandler: completionHandler)
        playerNode.play()
        isPlaying = true
    }

    func setSourcePosition(x: Float, z: Float) {
        sourcePosition = AVAudio3DPoint(x: x, y: heightY, z: z)
        playerNode.position = sourcePosition
    }

    func stop() {
        playerNode.stop()
        audioEngine.stop()
        isPlaying = false
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
}
