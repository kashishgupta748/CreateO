import Foundation
import SwiftUI

enum DesignType: String, Codable {
    case image
    case video
}

enum LayoutMode {
    case grid
    case week
    case month
    case year
}

enum StickerTab {
    case recent
    case newSticker
    case emojis
    case shapes
}

struct Design: Identifiable, Codable {
    let id: UUID
    var designName: String
    var createdAt: Date = Date()
    var updatedAt: Date?
    var isFavorite: Bool
    var designType: DesignType
    var designHeight = 270
    var designWidth = 180
    var designPath: String
    var thumbnailPath: String
    var albumID: UUID?
    var cloudSynced = false
    var projectPath: String? = nil
}

struct Album: Identifiable, Codable {
    let id: UUID
    var albumName: String
    var createdAt: Date = Date()
    var updatedAt: Date?
    var albumPath: String
    var thumbnailPath: String
    var albumDesignIDs: [UUID]
}

enum ElementType: String, Codable {
    case sticker
    case shape
    case emojis
    case text
    case template
    case image
    case stroke
}

enum Filter: String, Codable, CaseIterable {
    case original
    case smooth
    case animeStyle
    case watercolor
    case pencilcolor
    case crayon
    case sketch
    case doodle

    var title: String {
        switch self {
        case .original: return "Original"
        case .smooth: return "Smooth"
        case .animeStyle: return "Anime"
        case .watercolor: return "Watercolor"
        case .pencilcolor: return "Pencil"
        case .crayon: return "Crayon"
        case .sketch: return "Sketch"
        case .doodle: return "Doodle"
        }
    }
    
    var icon: String {
        switch self {
        case .original: return "photo"
        case .smooth: return "wind"
        case .animeStyle: return "sparkles"
        case .watercolor: return "paintpalette"
        case .pencilcolor: return "pencil"
        case .crayon: return "scribble"
        case .sketch: return "pencil.tip"
        case .doodle: return "lasso"
        }
    }
}

struct Element: Identifiable, Codable, Equatable {
    let id: UUID
    var elementType: ElementType?
    var x: Double
    var y: Double
    var scale: Double = 1.0
    var rotation: Double = 0.0
    var height: Double
    var width: Double
    var elementPath: String
    var elementFilter: Filter?
    var borderWidth: Double = 0
    var borderColor: SavedColor = SavedColor(red: 0, green: 0, blue: 0, alpha: 1)
    var zIndex: Int

    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case elementType
        case x
        case y
        case scale
        case rotation
        case height
        case width
        case elementPath
        case elementFilter
        case borderWidth
        case borderColor
        case zIndex
    }

    init(
        id: UUID,
        elementType: ElementType?,
        x: Double,
        y: Double,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        height: Double,
        width: Double,
        elementPath: String,
        elementFilter: Filter?,
        borderWidth: Double = 0,
        borderColor: SavedColor = SavedColor(red: 0, green: 0, blue: 0, alpha: 1),
        zIndex: Int
    ) {
        self.id = id
        self.elementType = elementType
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.height = height
        self.width = width
        self.elementPath = elementPath
        self.elementFilter = elementFilter
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.zIndex = zIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        elementType = try container.decodeIfPresent(ElementType.self, forKey: .elementType)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0.0
        height = try container.decode(Double.self, forKey: .height)
        width = try container.decode(Double.self, forKey: .width)
        elementPath = try container.decode(String.self, forKey: .elementPath)
        elementFilter = try container.decodeIfPresent(Filter.self, forKey: .elementFilter)
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0
        borderColor = try container.decodeIfPresent(SavedColor.self, forKey: .borderColor)
            ?? SavedColor(red: 0, green: 0, blue: 0, alpha: 1)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
    }
}

struct CanvasImage: Identifiable {
    let id = UUID()
    var image: UIImage
    var element: Element
    var isVisible: Bool = true
    var lastPosition: CGSize = .zero
    var lastScale: CGFloat = 1.0
    var lastRotation: Angle = .zero
    var cachedFilteredImage: UIImage? = nil
}

struct CanvasText: Identifiable {
    var id: UUID = UUID()
    var text: String
    var fontName: String
    var fontSize: CGFloat
    var textColor: Color
    var zIndex: Int = 0
    var isVisible: Bool = true
    var position: CGSize = .zero
    var rotation: Angle = .zero
    var lastPosition: CGSize = .zero
    var lastFontSize: CGFloat
    var lastRotation: Angle = .zero

    var uiFont: UIFont {
        UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }
}

struct SavedDesignProject: Codable {
    var designName: String
    var canvasColor: SavedColor
    var images: [SavedCanvasImage]
    var texts: [SavedCanvasText]
    var brushLayer: SavedBrushLayer?
}

struct SavedCanvasImage: Codable {
    var imageRelativePath: String
    var element: Element
    var isVisible: Bool
}

struct SavedCanvasText: Codable {
    var id: UUID
    var text: String
    var fontName: String
    var fontSize: Double
    var textColor: SavedColor
    var zIndex: Int
    var isVisible: Bool
    var positionX: Double
    var positionY: Double
    var rotationRadians: Double
}

struct SavedBrushLayer: Codable {
    var drawingData: Data
    var zIndex: Int
    var isVisible: Bool
}
struct PhotoLayout: Identifiable {
    let id = UUID()
    let imageName: String
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let widthFraction: CGFloat
    let heightFraction: CGFloat
}

enum PageLayouts {

    static let stacked: [PhotoLayout] = [
        PhotoLayout(imageName: "1", x: 0, y: 0, rotation: -8, widthFraction: 0.6, heightFraction: 0.45),
        PhotoLayout(imageName: "2", x: 0, y: 0, rotation: 6, widthFraction: 0.56, heightFraction: 0.43),
        PhotoLayout(imageName: "3", x: 0, y: 0, rotation: -5, widthFraction: 0.54, heightFraction: 0.42),
        PhotoLayout(imageName: "4", x: 0, y: 0, rotation: 4, widthFraction: 0.52, heightFraction: 0.40),
        PhotoLayout(imageName: "5", x: 0, y: 0, rotation: -3, widthFraction: 0.50, heightFraction: 0.38),
        PhotoLayout(imageName: "6", x: 0, y: 0, rotation: 2, widthFraction: 0.48, heightFraction: 0.36)
    ]

    static let grid: [PhotoLayout] = [
        PhotoLayout(imageName: "1", x: -0.25, y: -0.333, rotation: 0, widthFraction: 0.5, heightFraction: 0.333),
        PhotoLayout(imageName: "3", x: -0.25, y: 0.0, rotation: 0, widthFraction: 0.5, heightFraction: 0.333),
        PhotoLayout(imageName: "5", x: -0.25, y: 0.333, rotation: 0, widthFraction: 0.5, heightFraction: 0.333),
        PhotoLayout(imageName: "2", x: 0.25, y: -0.333, rotation: 0, widthFraction: 0.5, heightFraction: 0.333),
        PhotoLayout(imageName: "4", x: 0.25, y: 0.0, rotation: 0, widthFraction: 0.5, heightFraction: 0.333),
        PhotoLayout(imageName: "6", x: 0.25, y: 0.333, rotation: 0, widthFraction: 0.5, heightFraction: 0.333)
    ]
}


struct SavedColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero

        if !uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let resolved = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }

    var color: Color {
        Color(uiColor: UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)))
    }
}

// MARK: - Shared Albums

struct SharedAlbum: Identifiable, Codable {
    let id: UUID
    var albumName: String
    var ownerName: String
    var ownerID: UUID
    var createdAt: Date = Date()
    var updatedAt: Date?
    var thumbnailPath: String
    var designIDs: [UUID]
    var collaborators: [Collaborator]
    var activities: [AlbumActivity]
}

struct Collaborator: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var email: String
    var avatarColorHex: String
    var isCurrentUser: Bool
}

struct AlbumActivity: Identifiable, Codable {
    let id: UUID
    var userName: String
    var userEmail: String
    var activityType: String // "created", "joined", "added_design", "removed_design", "renamed_album"
    var detail: String
    var timestamp: Date = Date()
}

// MARK: - Color Hex & Avatar Helpers

extension Color {
    init?(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        
        if cString.count != 6 {
            return nil
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}

struct CollaboratorAvatarView: View {
    let collaborator: Collaborator
    var size: CGFloat = 36
    var fontSize: CGFloat = 12
    
    private var initials: String {
        let parts = collaborator.name.components(separatedBy: " ")
        if parts.count >= 2 {
            let first = parts[0].first.map(String.init) ?? ""
            let second = parts[1].first.map(String.init) ?? ""
            return (first + second).uppercased()
        } else if let first = collaborator.name.first {
            return String(first).uppercased()
        }
        return ""
    }
    
    private var avatarColor: Color {
        Color(hex: collaborator.avatarColorHex) ?? Color.accentColor
    }
    
    var body: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}


