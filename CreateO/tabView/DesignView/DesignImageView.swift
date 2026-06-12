import SwiftUI

enum DesignImageLoader {
    static func image(for path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }

        if let image = UIImage(contentsOfFile: path) {
            return image
        }

        return UIImage(named: path)
    }
}

struct DesignImageView: View {
    let path: String

    private var uiImage: UIImage? {
        DesignImageLoader.image(for: path)
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}
