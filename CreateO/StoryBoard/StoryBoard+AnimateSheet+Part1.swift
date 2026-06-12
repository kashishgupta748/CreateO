import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {


    var animateSheetDetent: PresentationDetent {
        switch animationApplyMode {
        case .allPages:
            return .height(286)
        case .singleGap:
            return .height(236)
        }
    }

    var animateSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(StoryTransition.allCases) { item in
                            Button {
                                transitionDraft = item
                                if case .singleGap = animationApplyMode {
                                    applySelectedSingleGapTransition(item)
                                }
                            } label: {
                                StoryTransitionCard(
                                    transition: item,
                                    isSelected: transitionDraft == item
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Spacer(minLength: 0)

                Button {
                    applyTransitionDraft(mode: .allPages)
                } label: {
                    Text("Apply between all pages")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .navigationTitle("Animate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAnimateSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
