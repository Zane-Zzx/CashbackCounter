import SwiftUI

struct CreditCardView: View {
    var bankName: String
    var type: String
    var endNum: String
    var colors: [Color]
    var cardImageData: Data? = nil
    var displayHeight: CGFloat? = nil
    var displayWidth: CGFloat? = nil

    private static let imageCache = NSCache<NSData, UIImage>()

    private var cachedImage: UIImage? {
        guard let data = cardImageData else { return nil }
        if let cached = Self.imageCache.object(forKey: data as NSData) {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        Self.imageCache.setObject(image, forKey: data as NSData)
        return image
    }

    private var renderHeight: CGFloat {
        if let displayWidth { return displayWidth / 1.586 }
        return displayHeight ?? 200
    }

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: renderHeight * 0.9, height: renderHeight)
                .offset(x: renderHeight * 0.7, y: -renderHeight * 0.2)

            if let uiImage = cachedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            }

            VStack(alignment: .leading) {
                if cardImageData == nil {
                    HStack {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: renderHeight * 0.1))
                        Spacer()
                        Text(bankName + " " + type)
                            .font(.system(size: renderHeight * 0.06, weight: .bold))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(5)
                    }
                }
                Spacer()
                HStack {
                    Text("**** **** **** \(endNum)")
                        .font(.system(size: renderHeight * 0.09))
                }
            }
            .padding(renderHeight * 0.12)
            .foregroundColor(.white)
        }
        .modifier(CardFrameModifier(displayWidth: displayWidth, displayHeight: displayHeight))
        .cornerRadius(renderHeight * 0.09)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

private struct CardFrameModifier: ViewModifier {
    let displayWidth: CGFloat?
    let displayHeight: CGFloat?

    func body(content: Content) -> some View {
        if let displayWidth {
            content.frame(width: displayWidth, height: displayWidth / 1.586)
        } else {
            content.aspectRatio(1.586, contentMode: .fit)
                .frame(height: displayHeight ?? 200)
        }
    }
}
