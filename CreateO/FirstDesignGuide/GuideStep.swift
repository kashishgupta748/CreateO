import SwiftUI

enum GuideAnchor: String, Hashable {
    case homeCreate
    case editorCanvas
    case editorUpload
    case editorDoodle
    case editorColors
    case editorFilters
    case imageBackground
    case imageBorder
    case editorText
    case editorStickers
    case editorAdjustments
    case editorSave
}

enum GuideTooltipPlacement {
    case top
    case bottom
    case automatic
}

enum GuideStep: String, CaseIterable, Identifiable {
    case homeCreate
    case editorColors
    case uploadPhoto
    case editorFilters
    case longPressForBackground
    case removeBackground
    case longPressForBorder
    case addBorder
    case editorStickers
    case editorText
    case editorDoodle
    case editorAdjustments
    case saveDesign

    var id: String { rawValue }

    var anchor: GuideAnchor {
        switch self {
        case .homeCreate:
            return .homeCreate
        case .editorColors:
            return .editorColors
        case .uploadPhoto:
            return .editorUpload
        case .editorFilters:
            return .editorFilters
        case .longPressForBackground, .longPressForBorder:
            return .editorCanvas
        case .removeBackground:
            return .imageBackground
        case .addBorder:
            return .imageBorder
        case .editorText:
            return .editorText
        case .editorStickers:
            return .editorStickers
        case .editorDoodle:
            return .editorDoodle
        case .editorAdjustments:
            return .editorAdjustments
        case .saveDesign:
            return .editorSave
        }
    }

    var title: String {
        switch self {
        case .homeCreate:
            return "Open your canvas"
        case .editorColors:
            return "Start with a template"
        case .uploadPhoto:
            return "Add your photo"
        case .editorFilters:
            return "Try a filter"
        case .longPressForBackground:
            return "Open photo actions"
        case .removeBackground:
            return "Remove background"
        case .longPressForBorder:
            return "Open photo actions again"
        case .addBorder:
            return "Add a border"
        case .editorText:
            return "Add words"
        case .editorStickers:
            return "Drop in stickers"
        case .editorDoodle:
            return "Create the sketch moment"
        case .editorAdjustments:
            return "Draw with Brush"
        case .saveDesign:
            return "Save to your collection"
        }
    }

    var message: String {
        switch self {
        case .homeCreate:
            return "Tap Create Your First Design to open a blank canvas. Then I’ll guide you one step at a time."
        case .editorColors:
            return "Tap Template first and choose a canvas style or color mood."
        case .uploadPhoto:
            return "Now tap Upload and choose a photo for this design."
        case .editorFilters:
            return "Tap Filter and choose a look. The guide will continue once you pick one."
        case .longPressForBackground:
            return "Long press the photo on the canvas to open hidden photo actions."
        case .removeBackground:
            return "Tap Background Remove to cut the subject out of the photo."
        case .longPressForBorder:
            return "Long press the photo again to open the same photo actions menu."
        case .addBorder:
            return "Tap Border to add an outline and make the photo pop."
        case .editorText:
            return "Tap Text and type your title or caption."
        case .editorStickers:
            return "Tap Sticker to add accents, shapes, and expressive details."
        case .editorDoodle:
            return "Tap Doodle to apply the sketch effect."
        case .editorAdjustments:
            return "Tap Brush and draw a small hand-made detail."
        case .saveDesign:
            return "Tap the checkmark and save your design to Designs or an album."
        }
    }

    var symbol: String {
        switch self {
        case .homeCreate:
            return "sparkles"
        case .editorColors:
            return "square.grid.2x2"
        case .uploadPhoto:
            return "photo.badge.plus.fill"
        case .editorFilters:
            return "wand.and.sparkles"
        case .longPressForBackground, .longPressForBorder:
            return "hand.tap.fill"
        case .removeBackground:
            return "person.crop.square.fill"
        case .addBorder:
            return "square.dashed"
        case .editorStickers:
            return "face.smiling.inverse"
        case .editorText:
            return "textformat"
        case .editorDoodle:
            return "scribble.variable"
        case .editorAdjustments:
            return "paintbrush.pointed.fill"
        case .saveDesign:
            return "checkmark.circle.fill"
        }
    }

    var actionHint: String {
        switch self {
        case .homeCreate:
            return "Tap the button"
        case .uploadPhoto:
            return "Add photo"
        case .longPressForBackground, .longPressForBorder:
            return "Long press"
        case .editorFilters:
            return "Pick a filter"
        case .editorText:
            return "Type text"
        case .editorDoodle:
            return "Apply effect"
        case .editorAdjustments:
            return "Draw once"
        case .saveDesign:
            return "Save design"
        default:
            return "Use this tool"
        }
    }

    var tooltipPlacement: GuideTooltipPlacement {
        switch self {
        case .homeCreate,
             .editorColors,
             .uploadPhoto,
             .editorFilters,
             .longPressForBackground,
             .longPressForBorder,
             .editorStickers,
             .editorText,
             .editorDoodle,
             .editorAdjustments:
            return .top
        case .saveDesign:
            return .bottom
        case .removeBackground,
             .addBorder:
            return .automatic
        }
    }

    var tooltipEstimatedHeight: CGFloat {
        switch self {
        case .homeCreate, .saveDesign:
            return 182
        default:
            return 170
        }
    }

    var progressIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var isFinalStep: Bool {
        self == Self.allCases.last
    }

    var skipDestination: GuideStep? {
        switch self {
        case .longPressForBackground:
            return .longPressForBorder
        case .longPressForBorder:
            return .editorStickers
        default:
            return next()
        }
    }

    func next() -> GuideStep? {
        let steps = Self.allCases
        guard let index = steps.firstIndex(of: self),
              steps.indices.contains(index + 1) else {
            return nil
        }
        return steps[index + 1]
    }
}
