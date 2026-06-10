import AppKit
import Foundation

@MainActor
final class ImportSessionStore: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    @Published var selectedVolumeID: VolumeInfo.ID?
    @Published var sourceURL: URL?
    @Published var destinationURL: URL?
    @Published var items: [MediaItem] = []
    @Published var selectedItemIDs: Set<MediaItem.ID> = []
    @Published var filter: ImportFilter = .new
    @Published var searchText: String = ""
    @Published var isScanning = false
    @Published var isClassifying = false
    @Published var isImporting = false
    @Published var isIndexing = false
    @Published var progress = ImportProgress()
    @Published var statusMessage = "Choose a source and destination."
    @Published var errorMessage: String?
    @Published var ledgerRecordCount: Int?

    private let volumeService = VolumeService()
    private let scanner = MediaScanner()
    private let fingerprintService = FileFingerprintService()
    private let pathBuilder = DestinationPathBuilder()
    private let importService = ImportService()

    private var ledger: ImportLedger?
    private var classificationTask: Task<Void, Never>?
    private var selectionAnchorItemID: MediaItem.ID?

    var filteredItems: [MediaItem] {
        items.filter { item in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .new:
                matchesFilter = item.status == .pending || item.status == .failed
            case .imported:
                matchesFilter = item.status == .imported
            case .conflicts:
                matchesFilter = item.status == .conflict || item.status == .importedMissing || item.status == .failed
            }

            guard matchesFilter else {
                return false
            }

            guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return true
            }

            return item.filename.localizedCaseInsensitiveContains(searchText)
                || item.relativePath.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedItems: [MediaItem] {
        items.filter { selectedItemIDs.contains($0.id) && $0.isSelectableForImport }
    }

    var canImportSelection: Bool {
        destinationURL != nil && !selectedItems.isEmpty && !isImporting
    }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.byteCount }
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.byteCount }
    }

    init() {
        sourceURL = BookmarkStore.resolveSource()
        destinationURL = BookmarkStore.resolveDestination()

        configureLedger()

        Task {
            await refreshVolumes()
        }
    }

    func refreshVolumes() async {
        volumes = volumeService.mountedVolumes()

        if let selectedVolumeID, !volumes.contains(where: { $0.id == selectedVolumeID }) {
            self.selectedVolumeID = nil
        }
    }

    func selectVolume(_ volume: VolumeInfo) {
        classificationTask?.cancel()
        selectedVolumeID = volume.id
        sourceURL = volume.url
        BookmarkStore.saveSource(volume.url)
        items = []
        selectedItemIDs = []
        selectionAnchorItemID = nil
        statusMessage = "Selected \(volume.name)."
    }

    func chooseSourceFolder() {
        guard let url = chooseDirectory(title: "Choose Source Folder", prompt: "Use as Source") else {
            return
        }

        classificationTask?.cancel()
        selectedVolumeID = nil
        sourceURL = url
        BookmarkStore.saveSource(url)
        items = []
        selectedItemIDs = []
        selectionAnchorItemID = nil
        statusMessage = "Selected \(url.lastPathComponent)."
    }

    func chooseDestinationFolder() {
        guard let url = chooseDirectory(title: "Choose Destination Folder", prompt: "Use as Destination") else {
            return
        }

        destinationURL = url
        BookmarkStore.saveDestination(url)
        statusMessage = "Destination set to \(url.lastPathComponent)."
    }

    func scanSource() async {
        guard let sourceURL else {
            errorMessage = AppError.missingSource.localizedDescription
            return
        }

        classificationTask?.cancel()
        isScanning = true
        statusMessage = "Scanning \(sourceURL.lastPathComponent)..."
        selectedItemIDs = []
        selectionAnchorItemID = nil
        progress = ImportProgress(currentFilename: nil, completedCount: 0, totalCount: 0, currentMessage: "Scanning source")

        do {
            let scannedItems = try await BookmarkStore.withSecurityScopedAccess(to: sourceURL) {
                try await Task.detached(priority: .userInitiated) {
                    try self.scanner.scan(source: sourceURL)
                }.value
            }

            items = scannedItems
            statusMessage = "\(scannedItems.count) media files found."
            isScanning = false
            progress = ImportProgress()
            startClassification()
        } catch {
            isScanning = false
            progress = ImportProgress()
            errorMessage = error.localizedDescription
            statusMessage = "Scan failed."
        }
    }

    func startClassification() {
        classificationTask?.cancel()

        guard ledger != nil, !items.isEmpty else {
            return
        }

        classificationTask = Task { [weak self] in
            await self?.classifyItems()
        }
    }

    func importSelected() async {
        guard let destinationURL else {
            errorMessage = AppError.missingDestination.localizedDescription
            return
        }

        guard let ledger else {
            configureLedger()
            guard self.ledger != nil else {
                return
            }
            return await importSelected()
        }

        let importItems = selectedItems
        guard !importItems.isEmpty else {
            return
        }

        classificationTask?.cancel()
        isImporting = true
        progress = ImportProgress(currentFilename: nil, completedCount: 0, totalCount: importItems.count, currentMessage: "Starting import")
        statusMessage = "Importing \(importItems.count) files..."

        guard let sourceURL else {
            errorMessage = AppError.missingSource.localizedDescription
            isImporting = false
            progress = ImportProgress()
            return
        }

        do {
            try await BookmarkStore.withSecurityScopedAccess(to: sourceURL) {
                try await BookmarkStore.withSecurityScopedAccess(to: destinationURL) {
                    for (index, item) in importItems.enumerated() {
                        try Task.checkCancellation()
                        progress = ImportProgress(
                            currentFilename: item.filename,
                            completedCount: index,
                            totalCount: importItems.count,
                            currentMessage: "Copying and verifying"
                        )
                        updateItem(id: item.id) { updated in
                            updated.status = .importing
                            updated.errorMessage = nil
                        }

                        do {
                            let record = try await importService.importItem(item, destinationRoot: destinationURL, ledger: ledger)
                            updateItem(id: item.id) { updated in
                                updated.status = .imported
                                updated.hash = record.contentHash
                                updated.destinationPath = record.destinationPath
                                updated.destinationAbsolutePath = record.destinationAbsolutePath
                                updated.errorMessage = nil
                            }
                            selectedItemIDs.remove(item.id)
                        } catch {
                            updateItem(id: item.id) { updated in
                                updated.status = .failed
                                updated.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }

            progress = ImportProgress(currentFilename: nil, completedCount: importItems.count, totalCount: importItems.count, currentMessage: "Done")
            ledgerRecordCount = try? await ledger.count()
            statusMessage = "Import complete."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Import stopped."
        }

        isImporting = false
        progress = ImportProgress()
    }

    func indexExistingDestination() async {
        guard let destinationURL else {
            errorMessage = AppError.missingDestination.localizedDescription
            return
        }

        guard let ledger else {
            configureLedger()
            guard self.ledger != nil else {
                return
            }
            return await indexExistingDestination()
        }

        classificationTask?.cancel()
        isIndexing = true
        statusMessage = "Indexing existing destination media..."
        progress = ImportProgress(currentFilename: nil, completedCount: 0, totalCount: 0, currentMessage: "Scanning destination")

        do {
            let destinationItems = try await BookmarkStore.withSecurityScopedAccess(to: destinationURL) {
                try await Task.detached(priority: .userInitiated) {
                    try self.scanner.scan(source: destinationURL, excludedDirectoryNames: [ImportLedger.directoryName])
                }.value
            }

            progress = ImportProgress(currentFilename: nil, completedCount: 0, totalCount: destinationItems.count, currentMessage: "Fingerprinting destination")

            for (index, item) in destinationItems.enumerated() {
                try Task.checkCancellation()
                progress = ImportProgress(
                    currentFilename: item.filename,
                    completedCount: index,
                    totalCount: destinationItems.count,
                    currentMessage: "Fingerprinting destination"
                )

                let fingerprint = try await Task.detached(priority: .utility) {
                    try self.fingerprintService.fingerprint(for: item.url, byteCount: item.byteCount)
                }.value

                let now = Date()
                let destinationVolumeUUID = try? destinationURL.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
                let record = ImportRecord(
                    id: nil,
                    contentHash: fingerprint,
                    byteCount: item.byteCount,
                    originalFilename: item.filename,
                    sourceVolumeUUID: item.sourceVolumeUUID,
                    sourceRelativePath: item.relativePath,
                    captureDate: item.captureDate,
                    mediaKind: item.mediaKind,
                    destinationRootPath: destinationURL.path,
                    destinationPath: item.relativePath,
                    destinationAbsolutePath: item.url.path,
                    destinationVolumeUUID: destinationVolumeUUID,
                    importedAt: now,
                    verifiedAt: now
                )
                try await ledger.insert(record)
            }

            ledgerRecordCount = try await ledger.count()
            progress = ImportProgress(currentFilename: nil, completedCount: destinationItems.count, totalCount: destinationItems.count, currentMessage: "Done")
            statusMessage = "Indexed \(destinationItems.count) destination files."
            isIndexing = false
            progress = ImportProgress()
            startClassification()
        } catch {
            isIndexing = false
            progress = ImportProgress()
            errorMessage = error.localizedDescription
            statusMessage = "Indexing failed."
        }
    }

    func toggleSelection(for item: MediaItem) {
        guard item.isSelectableForImport else {
            return
        }

        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.shift),
           let selectionAnchorItemID,
           selectRange(from: selectionAnchorItemID, to: item.id) {
            return
        }

        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
        selectionAnchorItemID = item.id
    }

    func selectAllVisibleNew() {
        let importableIDs = filteredItems.filter(\.isSelectableForImport).map(\.id)
        selectedItemIDs.formUnion(importableIDs)
        selectionAnchorItemID = importableIDs.last ?? selectionAnchorItemID
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
        selectionAnchorItemID = nil
    }

    func revealSource(_ item: MediaItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func revealDestination(_ item: MediaItem) {
        if let destinationAbsolutePath = item.destinationAbsolutePath {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destinationAbsolutePath)])
            return
        }

        if let destinationURL = destinationURL,
           let destinationPath = item.destinationPath {
            let url = PathUtilities.url(forRelativePath: destinationPath, root: destinationURL)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func classifyItems() async {
        guard let sourceURL, let ledger else {
            return
        }

        await BookmarkStore.withSecurityScopedAccess(to: sourceURL) {
            if let destinationURL {
                await BookmarkStore.withSecurityScopedAccess(to: destinationURL) {
                    await classifyItemsWithAccess(destinationURL: destinationURL, ledger: ledger)
                }
            } else {
                await classifyItemsWithAccess(destinationURL: nil, ledger: ledger)
            }
        }
    }

    private func classifyItemsWithAccess(destinationURL: URL?, ledger: ImportLedger) async {
        isClassifying = true
        progress = ImportProgress(currentFilename: nil, completedCount: 0, totalCount: items.count, currentMessage: "Checking imports")

        let snapshot = items

        for (index, item) in snapshot.enumerated() {
            if Task.isCancelled {
                break
            }

            progress = ImportProgress(
                currentFilename: item.filename,
                completedCount: index,
                totalCount: snapshot.count,
                currentMessage: "Checking imports"
            )

            do {
                let fingerprint = try await Task.detached(priority: .utility) {
                    try self.fingerprintService.fingerprint(for: item.url, byteCount: item.byteCount)
                }.value

                let classification = try await classify(item: item, fingerprint: fingerprint, destinationURL: destinationURL, ledger: ledger)

                updateItem(id: item.id) { updated in
                    guard updated.status != .importing else {
                        return
                    }
                    updated.hash = fingerprint
                    updated.status = classification.status
                    updated.destinationPath = classification.destinationPath
                    updated.destinationAbsolutePath = classification.destinationAbsolutePath
                    updated.errorMessage = nil
                }
            } catch {
                updateItem(id: item.id) { updated in
                    guard updated.status != .importing else {
                        return
                    }
                    updated.status = .failed
                    updated.errorMessage = error.localizedDescription
                }
            }
        }

        if !Task.isCancelled {
            progress = ImportProgress(currentFilename: nil, completedCount: snapshot.count, totalCount: snapshot.count, currentMessage: "Done")
            ledgerRecordCount = try? await ledger.count()
            statusMessage = "Import check complete."
        }

        isClassifying = false
        progress = ImportProgress()
    }

    private func classify(
        item: MediaItem,
        fingerprint: String,
        destinationURL: URL?,
        ledger: ImportLedger
    ) async throws -> (status: ImportStatus, destinationPath: String?, destinationAbsolutePath: String?) {
        if let record = try await ledger.record(contentHash: fingerprint, byteCount: item.byteCount) {
            return (.imported, record.destinationPath, record.destinationAbsolutePath)
        }

        guard let destinationURL else {
            return (.pending, nil, nil)
        }

        let preferredRelativePath = pathBuilder.preferredRelativePath(for: item)
        let preferredURL = PathUtilities.url(forRelativePath: preferredRelativePath, root: destinationURL)

        guard FileManager.default.fileExists(atPath: preferredURL.path) else {
            return (.pending, preferredRelativePath, preferredURL.path)
        }

        let destinationFingerprint = try fingerprintService.fingerprint(for: preferredURL, byteCount: item.byteCount)
        if destinationFingerprint == fingerprint {
            let now = Date()
            let destinationVolumeUUID = try? destinationURL.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
            let adoptedRecord = ImportRecord(
                id: nil,
                contentHash: fingerprint,
                byteCount: item.byteCount,
                originalFilename: item.filename,
                sourceVolumeUUID: item.sourceVolumeUUID,
                sourceRelativePath: item.relativePath,
                captureDate: item.captureDate,
                mediaKind: item.mediaKind,
                destinationRootPath: destinationURL.path,
                destinationPath: preferredRelativePath,
                destinationAbsolutePath: preferredURL.path,
                destinationVolumeUUID: destinationVolumeUUID,
                importedAt: now,
                verifiedAt: now
            )
            try await ledger.insert(adoptedRecord)
            return (.imported, preferredRelativePath, preferredURL.path)
        }

        return (.conflict, preferredRelativePath, preferredURL.path)
    }

    private func configureLedger() {
        do {
            let openedLedger = try ImportLedger()
            ledger = openedLedger
            Task {
                ledgerRecordCount = try? await openedLedger.count()
            }
        } catch {
            ledger = nil
            ledgerRecordCount = nil
            errorMessage = error.localizedDescription
        }
    }

    private func chooseDirectory(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func updateItem(id: MediaItem.ID, _ mutate: (inout MediaItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutate(&items[index])
    }

    @discardableResult
    private func selectRange(from anchorID: MediaItem.ID, to targetID: MediaItem.ID) -> Bool {
        let visibleItems = filteredItems

        guard let anchorIndex = visibleItems.firstIndex(where: { $0.id == anchorID }),
              let targetIndex = visibleItems.firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        let rangeIDs = visibleItems[lowerBound...upperBound]
            .filter(\.isSelectableForImport)
            .map(\.id)

        selectedItemIDs.formUnion(rangeIDs)
        selectionAnchorItemID = targetID
        return true
    }
}
