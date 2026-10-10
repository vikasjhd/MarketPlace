import SwiftUI

struct ListingEditorView: View {
    @Environment(ListingRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ListingEditorViewModel
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
        }
        .navigationTitle(viewModel.isNew ? "New listing" : "Edit listing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
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
        do {
            if try viewModel.save(to: repository) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
