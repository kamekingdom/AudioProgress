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
    private var displayLink: CADisplayLink?
    private var sweepStartTime: CFTimeInterval?
    private let motionPeriod: Double = 3.0
    private let heightY: Float = 1.2
    private let frontZ: Float = -1.0
    private let backZ: Float = 1.0

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

    func playSpatialAudio(from sourceURL: URL) async throws {
        stopPlayback()
        let m4aURL: URL = try await exportAudio(from: sourceURL)
        try configureAudioSession()
        try setupEngineWithFile(at: m4aURL)
        startMotion()
    }

    func stopPlayback() {
        stopMotion()
        playerNode.stop()
        audioEngine.stop()
    }

    private func configureAudioSession() throws {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true, options: [])
        } catch {
            throw SpatialAudioError.audioSessionUnavailable
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

    private func setupEngineWithFile(at url: URL) throws {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw SpatialAudioError.fileUnavailable
        }

        if !audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.attach(playerNode)
        }
        if !audioEngine.attachedNodes.contains(environmentNode) {
            audioEngine.attach(environmentNode)
        }

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(environmentNode)
        audioEngine.connect(playerNode, to: environmentNode, format: audioFile.processingFormat)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.stop()
        audioEngine.reset()

        playerNode.stop()
        playerNode.renderingAlgorithm = .HRTF
        playerNode.position = AVAudio3DPoint(x: 0.0, y: heightY, z: frontZ)
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0.0, y: 0.0, z: 0.0)

        do {
            try audioEngine.start()
        } catch {
            throw SpatialAudioError.engineStartFailed
        }

        let completionHandler: () -> Void = { [weak self] in
            DispatchQueue.main.async {
                self?.stopPlayback()
            }
        }
        playerNode.scheduleFile(audioFile, at: nil, completionHandler: completionHandler)
        playerNode.play()
    }

    private func startMotion() {
        stopMotion()
        sweepStartTime = CACurrentMediaTime()
        let link: CADisplayLink = CADisplayLink(target: self, selector: #selector(updatePosition(_:)))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .default)
        displayLink = link
    }

    private func stopMotion() {
        displayLink?.invalidate()
        displayLink = nil
        sweepStartTime = nil
    }

    @objc private func updatePosition(_ link: CADisplayLink) {
        guard let startTime: CFTimeInterval = sweepStartTime else {
            sweepStartTime = link.timestamp
            return
        }
        let elapsed: Double = link.timestamp - startTime
        let cycle: Double = elapsed.truncatingRemainder(dividingBy: motionPeriod)
        let ratio: Double = cycle / motionPeriod
        let zDelta: Float = backZ - frontZ
        let zPosition: Float = frontZ + Float(ratio) * zDelta
        let position: AVAudio3DPoint = AVAudio3DPoint(x: 0.0, y: heightY, z: zPosition)
        playerNode.position = position
    }
}
