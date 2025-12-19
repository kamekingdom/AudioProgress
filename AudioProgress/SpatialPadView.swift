// Author: kamekingdom (2025-12-18)
//
//  SpatialPadView.swift
//  AudioProgress
//
//  Created by ChatGPT on 2025/12/18.

import SwiftUI

struct SpatialPadView: View {
    let heightLabel: String
    let rangeMeters: Float
    let currentPoint: CGPoint?
    let onPositionChanged: (_ x: Float, _ z: Float, _ displayPoint: CGPoint) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size: CGSize = geometry.size
            ZStack {
                Canvas { context, size in
                    drawGrid(in: size, context: &context)
                    drawHead(in: size, context: &context)
                    drawLabels(in: size, context: &context)
                    if let displayPoint: CGPoint = currentPoint {
                        drawSourcePoint(displayPoint, context: &context)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0.0)
                        .onChanged { gesture in
                            let point: CGPoint = gesture.location
                            let mapped: (Float, Float, CGPoint) = mapLocation(point, in: size)
                            onPositionChanged(mapped.0, mapped.1, mapped.2)
                        }
                        .onEnded { gesture in
                            let point: CGPoint = gesture.location
                            let mapped: (Float, Float, CGPoint) = mapLocation(point, in: size)
                            onPositionChanged(mapped.0, mapped.1, mapped.2)
                        }
                )
                VStack {
                    Spacer()
                    Text(heightLabel)
                        .font(.caption)
                        .padding(.bottom, 4.0)
                }
            }
        }
        .frame(height: 280.0)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12.0)
    }

    private func mapLocation(_ point: CGPoint, in size: CGSize) -> (Float, Float, CGPoint) {
        let radius: CGFloat = min(size.width, size.height) / 2.0
        let center: CGPoint = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let clampedX: CGFloat = max(-radius, min(radius, point.x - center.x))
        let clampedY: CGFloat = max(-radius, min(radius, point.y - center.y))
        let metersPerPoint: CGFloat = CGFloat(rangeMeters) / radius
        let xMeters: Float = Float(clampedX * metersPerPoint)
        let zMeters: Float = Float(clampedY * metersPerPoint)
        let displayPoint: CGPoint = CGPoint(x: center.x + clampedX, y: center.y + clampedY)
        return (xMeters, zMeters, displayPoint)
    }

    private func drawGrid(in size: CGSize, context: inout GraphicsContext) {
        let center: CGPoint = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        var path: Path = Path()
        path.move(to: CGPoint(x: center.x, y: 0.0))
        path.addLine(to: CGPoint(x: center.x, y: size.height))
        path.move(to: CGPoint(x: 0.0, y: center.y))
        path.addLine(to: CGPoint(x: size.width, y: center.y))
        context.stroke(path, with: .color(.gray.opacity(0.4)), lineWidth: 1.0)
    }

    private func drawHead(in size: CGSize, context: inout GraphicsContext) {
        let center: CGPoint = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let headRadius: CGFloat = 12.0
        var headPath: Path = Path(ellipseIn: CGRect(x: center.x - headRadius, y: center.y - headRadius, width: headRadius * 2.0, height: headRadius * 2.0))
        context.fill(headPath, with: .color(.blue.opacity(0.6)))
        let text: Text = Text("Head")
        context.draw(text, at: CGPoint(x: center.x, y: center.y + 20.0))
    }

    private func drawLabels(in size: CGSize, context: inout GraphicsContext) {
        let center: CGPoint = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let labelOffset: CGFloat = min(size.width, size.height) / 2.0 - 16.0
        context.draw(Text("Front"), at: CGPoint(x: center.x, y: center.y - labelOffset))
        context.draw(Text("Back"), at: CGPoint(x: center.x, y: center.y + labelOffset))
        context.draw(Text("Left"), at: CGPoint(x: center.x - labelOffset, y: center.y))
        context.draw(Text("Right"), at: CGPoint(x: center.x + labelOffset, y: center.y))
    }

    private func drawSourcePoint(_ point: CGPoint, context: inout GraphicsContext) {
        let radius: CGFloat = 6.0
        let rect: CGRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2.0, height: radius * 2.0)
        let path: Path = Path(ellipseIn: rect)
        context.fill(path, with: .color(.red))
    }
}

#Preview {
    SpatialPadView(heightLabel: "Overhead plane y=1.2m", rangeMeters: 1.5, currentPoint: nil) { _, _, _ in
    }
    .padding()
}
