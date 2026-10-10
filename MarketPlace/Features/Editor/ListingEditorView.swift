import PhotosUI
import SwiftUI

struct ListingEditorView: View {
    @Environment(ListingRepository.self) private var repository
    @Environment(\.imageFileStore) private var fileStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ListingEditorViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(listing: Listing?) {
        _viewModel = State(initialValue: ListingEditorViewModel(listing: listing))
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("What are you selling?", text: $viewModel.draft.title)
                errorText(for: .title)
            }

            Section("Description") {
                TextField("Condition, size, pickup area…", text: $viewModel.draft.details, axis: .vertical)
                    .lineLimit(3...8)
                errorText(for: .details)
            }

            Section("Price") {
                HStack {
                    Text("₹")
                    TextField("0", text: $viewModel.draft.priceText)
                        .keyboardType(.decimalPad)
                }
                errorText(for: .price)
            }

            Section("Category") {
                Picker("Category", selection: $viewModel.draft.category) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Text(category.displayName)
                    }
                }
            }

            photosSection
        }
        .navigationTitle(viewModel.isNew ? "New listing" : "Edit listing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cancel()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                await run { try await viewModel.addPhotos(items, fileStore: fileStore) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                Task {
                    await run { try await viewModel.addPhoto(data, fileStore: fileStore) }
                }
            }
            .ignoresSafeArea()
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            if !viewModel.draft.images.isEmpty {
                HStack {
                    ForEach(viewModel.draft.images) { image in
                        ThumbnailView(image: image, pointSize: 80)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    viewModel.removePhoto(image)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove photo")
                            }
                    }
                }
            }

            if viewModel.photosLeft > 0 {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: viewModel.photosLeft,
                    matching: .images
                ) {
                    Label("Choose photos", systemImage: "photo.on.rectangle")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                    }
                }
            }

            errorText(for: .images)
        }
    }

    @ViewBuilder
    private func errorText(for field: ValidationIssue.Field) -> some View {
        if let message = viewModel.message(for: field) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func save() {
        Task {
            await run {
                if try await viewModel.save(to: repository, fileStore: fileStore) {
                    dismiss()
                }
            }
        }
    }

    private func cancel() {
        Task {
            await viewModel.cancel(fileStore: fileStore)
            dismiss()
        }
    }

    // Shows any error from the work in an alert.
    private func run(_ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
