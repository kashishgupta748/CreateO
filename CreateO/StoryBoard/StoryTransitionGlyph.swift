import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct StoryTransitionGlyph: View {
    let transition: StoryTransition

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.04)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                switch transition {
                case .none:
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.9))
                        .frame(width: 3, height: height * 0.78)
                        .rotationEffect(.degrees(42))
                case .dissolve:
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.32))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.55))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                case .circleWipe:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.78))
                            .frame(width: width * 0.78, height: height * 0.70)
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: height * 0.70, height: height * 0.70)
                    }
                case .slide:
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.28))
                            .frame(width: width * 0.22)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.86))
                    }
                    .padding(.horizontal, 8)
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentColor.opacity(0.9))
                            .offset(x: 14, y: 10)
                    }
                case .colorWipe:
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.16))
                            .frame(width: width * 0.16)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.32))
                            .frame(width: width * 0.14)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.55))
                            .frame(width: width * 0.16)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.88))
                    }
                    .padding(.horizontal, 8)
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentColor.opacity(0.9))
                            .offset(x: 12, y: 10)
                    }
                case .lineWipe:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.78))
                        .frame(width: width * 0.72, height: height * 0.72)
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.55))
                        .frame(width: 3, height: height * 0.98)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor.opacity(0.9))
                        .offset(x: 20, y: 12)
                case .matchAndMove:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.86))
                        .frame(width: width * 0.78, height: height * 0.70)
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Image(systemName: "sparkles")
                        Image(systemName: "sparkles")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                case .flow:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.82))
                        .frame(width: width * 0.54, height: height * 0.64)
                        .offset(x: 9)
                    VStack(spacing: 5) {
                        Capsule().fill(Color.accentColor.opacity(0.52)).frame(width: width * 0.32, height: 3)
                        Capsule().fill(Color.accentColor.opacity(0.34)).frame(width: width * 0.24, height: 3)
                        Capsule().fill(Color.accentColor.opacity(0.20)).frame(width: width * 0.16, height: 3)
                    }
                    .offset(x: -14)
                case .stack:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.24))
                        .frame(width: width * 0.62, height: height * 0.56)
                        .offset(y: 8)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.86))
                        .frame(width: width * 0.62, height: height * 0.56)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.accentColor.opacity(0.9))
                        .offset(x: 26, y: 11)
                case .chop:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: width * 0.72, height: height * 0.72)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.86))
                        .frame(width: width * 0.58, height: height * 0.72)
                        .mask(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 8,
                                bottomLeadingRadius: 8,
                                bottomTrailingRadius: 4,
                                topTrailingRadius: 16
                            )
                        )
                        .rotationEffect(.degrees(-12))
                        .offset(x: 10)
                }
            }
            .clipped()
        }
    }
}
