import SwiftUI

struct CardFacePickerView: View {
    @Binding var cardImageData: Data?
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var cardFaceSource: CardFaceSource

    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var pickedImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            CreditCardView(
                bankName: String(localized: "预览"),
                type: "",
                endNum: "8888",
                colors: [color1, color2],
                cardImageData: cardFaceSource == .gradient ? nil : cardImageData,
                displayHeight: 180
            )
            .padding(.bottom, 16)

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    faceButton(title: "拍照", icon: "camera.fill") {
                        showCamera = true
                    }
                }
                faceButton(title: "相册", icon: "photo.on.rectangle") {
                    showImagePicker = true
                }
                faceButton(title: "渐变", icon: "paintpalette.fill") {
                    cardFaceSource = .gradient
                    cardImageData = nil
                }
            }

            if cardFaceSource == .gradient {
                VStack(spacing: 8) {
                    ColorPicker("渐变色 1", selection: $color1)
                    ColorPicker("渐变色 2", selection: $color2)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $pickedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $pickedImage, sourceType: .camera)
        }
        .onChange(of: pickedImage) { _, newImage in
            guard let image = newImage else { return }
            if let data = image.jpegData(compressionQuality: 0.9),
               let resized = resizeCardImage(data) {
                cardImageData = resized
                cardFaceSource = showCamera ? .camera : .photo
            }
            pickedImage = nil
        }
    }

    private func faceButton(title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .foregroundColor(.primary)
    }

    private func resizeCardImage(_ data: Data, targetWidth: CGFloat = 800) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let targetHeight = targetWidth / 1.586
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: targetHeight))
        let resized = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
