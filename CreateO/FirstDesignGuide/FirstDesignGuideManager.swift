import Foundation
import Observation

@Observable
final class FirstDesignGuideManager {
    var currentStep: GuideStep?
    private(set) var isCompleted = false

    @ObservationIgnored
    private var markCompleted: (() -> Void)?

    func configure(isCompleted: Bool, markCompleted: @escaping () -> Void) {
        self.isCompleted = isCompleted
        self.markCompleted = markCompleted

        if isCompleted {
            currentStep = nil
        }
    }

    func show(_ step: GuideStep) {
        guard !isCompleted else { return }
        withGuideAnimation {
            currentStep = step
        }
    }

    func showIfNeeded(_ step: GuideStep) {
        guard !isCompleted else { return }
        if currentStep == nil || currentStep == step {
            show(step)
        }
    }

    func advance(from step: GuideStep? = nil) {
        guard !isCompleted else { return }
        if let step, currentStep != step { return }

        guard let activeStep = currentStep,
              let nextStep = activeStep.next() else {
            complete()
            return
        }

        withGuideAnimation {
            currentStep = nextStep
        }
    }

    func skip() {
        guard !isCompleted else { return }
        guard let destination = currentStep?.skipDestination else {
            complete()
            return
        }

        withGuideAnimation {
            currentStep = destination
        }
    }

    func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        markCompleted?()

        withGuideAnimation {
            currentStep = nil
        }
    }

    private func withGuideAnimation(_ changes: () -> Void) {
        changes()
    }
}
