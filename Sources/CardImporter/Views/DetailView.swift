import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ImportSessionStore

    private let columns = [
        GridItem(.adaptive(minimum: 170, maximum: 230), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)

            Divider()

            if store.sourceURL == nil {
                EmptyStateView(
                    systemImage: "sdcard",
                    title: "No Source Selected",
                    actionTitle: "Choose Source Folder"
                ) {
                    store.chooseSourceFolder()
                }
            } else if store.items.isEmpty && !store.isScanning {
                EmptyStateView(
                    systemImage: "photo.stack",
                    title: "Ready to Scan",
                    actionTitle: "Scan Source"
                ) {
                    Task { await store.scanSource() }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.filteredItems) { item in
                            MediaGridItemView(
                                item: item,
                                isSelected: store.selectedItemIDs.contains(item.id),
                                showDestinationAction: item.destinationPath != nil
                            ) {
                                store.toggleSelection(for: item)
                            } revealSource: {
                                store.revealSource(item)
                            } revealDestination: {
                                store.revealDestination(item)
                            }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search media")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.scanSource() }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(store.sourceURL == nil || store.isScanning || store.isImporting)

                Button {
                    store.selectAllVisibleNew()
                } label: {
                    Label("Select Importable", systemImage: "checklist")
                }
                .disabled(store.filteredItems.allSatisfy { !$0.isSelectableForImport })

                Button {
                    store.clearSelection()
                } label: {
                    Label("Clear Selection", systemImage: "xmark.circle")
                }
                .disabled(store.selectedItemIDs.isEmpty)

                Button {
                    Task { await store.importSelected() }
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.canImportSelection)
                .keyboardShortcut("i", modifiers: [.command])
            }
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var store: ImportSessionStore

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Picker("Filter", selection: $store.filter) {
                    ForEach(ImportFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 330)

                Spacer()

                HeaderMetric(title: "Files", value: "\(store.items.count)")
                HeaderMetric(title: "Selected", value: "\(store.selectedItems.count)")
                HeaderMetric(title: "Size", value: ByteCountFormatting.string(from: store.selectedBytes))
            }

            if store.isScanning || store.isClassifying || store.isImporting || store.isIndexing {
                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: store.progress.totalCount > 0 ? store.progress.fractionCompleted : nil)
                    HStack {
                        Text(store.progress.currentMessage ?? "Working")
                        Spacer()
                        if let filename = store.progress.currentFilename {
                            Text(filename)
                                .truncationMode(.middle)
                        }
                        if store.progress.totalCount > 0 {
                            Text("\(store.progress.completedCount)/\(store.progress.totalCount)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }
}

private struct HeaderMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(minWidth: 74, alignment: .trailing)
    }
}

private struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 46))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)

            Button(action: action) {
                Text(actionTitle)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
