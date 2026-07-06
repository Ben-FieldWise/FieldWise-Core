//
//  FieldPhotoCapture.swift
//  Student Fieldwork App
//
//  Reusable photo capture UI for the Site Field Sheet: a combined
//  "Add Photo" control offering camera or photo library, built entirely
//  from native frameworks (UIKit's UIImagePickerController for the
//  camera, SwiftUI's PhotosPicker for the library — both iOS 16+,
//  no third-party dependencies).
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Camera capture wrapper

/// Wraps UIImagePickerController in camera mode. SwiftUI has no native
/// camera capture view pre-iOS 17, so this is the standard UIKit bridge.
struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - Add Photo control (camera or library)

/// A button that, when tapped, offers "Take Photo" or "Choose from Library",
/// then hands the resulting UIImage back via `onPhotoSelected`.
struct AddPhotoButton: View {
    var onPhotoSelected: (UIImage) -> Void
    var label: String = "Add Photo"
    var compact: Bool = false

    @State private var showingSourceChoice = false
    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        Group {
            if compact {
                Button {
                    showingSourceChoice = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("GeoGreen"))
                        .frame(width: 36, height: 36)
                        .background(Color("GeoGreen").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showingSourceChoice = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(label)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color("GeoGreen"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("GeoGreen").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showingSourceChoice, titleVisibility: .hidden) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showingCamera = true }
            }
            Button("Choose from Library") { presentPhotoPicker() }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView(
                onCapture: { image in
                    showingCamera = false
                    onPhotoSelected(image)
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $libraryPickerPresented, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        onPhotoSelected(image)
                    }
                }
                await MainActor.run {
                    photoPickerItem = nil
                }
            }
        }
    }

    // PhotosPicker needs its own presentation flag since it isn't part of
    // the confirmationDialog's button actions directly (those must be
    // simple synchronous toggles).
    @State private var libraryPickerPresented = false

    private func presentPhotoPicker() {
        libraryPickerPresented = true
    }
}

// MARK: - Photo gallery strip

/// Horizontal scrolling strip of thumbnails for a photo gallery (item-level
/// or site-level), with an "Add Photo" tile at the end and tap-to-preview /
/// delete support.
struct FieldPhotoGalleryStrip: View {
    @ObservedObject var store: SiteFieldSheetStore
    let photos: [FieldPhoto]
    var onAdd: (UIImage) -> Void
    var onDelete: (FieldPhoto) -> Void

    @State private var previewPhoto: FieldPhoto?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    thumbnail(for: photo)
                }
                AddPhotoButton(onPhotoSelected: onAdd, compact: true)
            }
        }
        .sheet(item: $previewPhoto) { photo in
            FieldPhotoPreviewView(store: store, photo: photo, onDelete: {
                onDelete(photo)
                previewPhoto = nil
            })
        }
    }

    @ViewBuilder
    private func thumbnail(for photo: FieldPhoto) -> some View {
        if let image = store.loadImage(for: photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                .onTapGesture { previewPhoto = photo }
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color("GeoSurface"))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
        }
    }
}

// MARK: - Full-screen photo preview with caption + delete

struct FieldPhotoPreviewView: View {
    @ObservedObject var store: SiteFieldSheetStore
    let photo: FieldPhoto
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = store.loadImage(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    Spacer()
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
