//
//  LibraryViewModel.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import Foundation
import Photos
import AppKit

struct TypographySettings: Equatable {
    var line1FontName: String = "New York"
    var line2FontName: String = "New York"
    var line1Size: CGFloat = 65
    var line2Size: CGFloat = 65
    var line1Kern: CGFloat = 1.3
    var line2Kern: CGFloat = 1.3
    var line2Baseline: CGFloat = -2
    var textColor: NSColor = .black
    
    static func == (lhs: TypographySettings, rhs: TypographySettings) -> Bool {
        return lhs.line1FontName == rhs.line1FontName &&
               lhs.line2FontName == rhs.line2FontName &&
               lhs.line1Size == rhs.line1Size &&
               lhs.line2Size == rhs.line2Size &&
               lhs.line1Kern == rhs.line1Kern &&
               lhs.line2Kern == rhs.line2Kern &&
               lhs.line2Baseline == rhs.line2Baseline &&
               lhs.textColor.isEqual(rhs.textColor)
    }
    
    // Create a hash for dependency tracking
    func settingsHash(with line1: String, line2: String) -> Int {
        var hasher = Hasher()
        hasher.combine(line1FontName)
        hasher.combine(line2FontName)
        hasher.combine(line1Size)
        hasher.combine(line2Size)
        hasher.combine(line1Kern)
        hasher.combine(line2Kern)
        hasher.combine(line2Baseline)
        
        // Convert to RGB colorspace to safely access components
        let rgbColor = textColor.usingColorSpace(.sRGB) ?? textColor
        hasher.combine(rgbColor.redComponent)
        hasher.combine(rgbColor.greenComponent)
        hasher.combine(rgbColor.blueComponent)
        hasher.combine(rgbColor.alphaComponent)
        
        hasher.combine(line1)
        hasher.combine(line2)
        return hasher.finalize()
    }
    
    static let line1FontOptions = ["SF Pro", "SF Pro Rounded", "New York", "Georgia", "Avenir", "Baskerville"]
    static let line2FontOptions = ["Patrick Hand", "Bradley Hand", "Marker Felt", "Noteworthy", "SF Pro", "New York", "Georgia"]
    static let colorOptions: [(String, NSColor)] = [
        ("Black", .black),
        ("Dark Gray", .darkGray),
        ("Navy", NSColor(red: 0, green: 0, blue: 0.5, alpha: 1))
    ]
}

struct PhotoItem: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    var line1: String  // Date/location line
    var line2: String  // Custom text line
    var isSelected: Bool = false
    var isLine1ManuallyEdited: Bool = false  // Track if line1 was manually edited
    
    init(asset: PHAsset) {
        self.asset = asset
        self.line1 = ""
        self.line2 = ""
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // Legacy support for single caption
    var caption: String {
        get { line2.isEmpty ? line1 : "\(line1)\n\(line2)" }
        set { 
            if newValue.contains("\n") {
                let lines = newValue.components(separatedBy: "\n")
                line1 = lines.first ?? ""
                line2 = lines.dropFirst().joined(separator: "\n")
            } else {
                line2 = newValue
            }
        }
    }
}

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var albums: [PHAssetCollection] = []
    @Published var selectedAlbumID: String?
    @Published var photoItems: [PhotoItem] = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var focusedItem: PhotoItem?
    @Published var typographySettings = TypographySettings()
    
    private let photoLibrary = PhotoLibrary.shared
    private var thumbnailCache: [String: NSImage] = [:]
    
    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestPhotoAccess() async -> Bool {
        let granted = await photoLibrary.requestAccess()
        authorizationStatus = photoLibrary.authorizationStatus
        return granted
    }
    
    func loadAlbums() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            let granted = await requestPhotoAccess()
            guard granted else {
                print("Photo access denied")
                return
            }
            return await loadAlbums()  // Recursively call after getting permission
        }
        
        let fetchedAlbums = await photoLibrary.fetchAlbums()
        albums = fetchedAlbums
    }
    
    func loadPhotosFromAlbum(_ albumID: String) async {
        guard let album = albums.first(where: { $0.localIdentifier == albumID }) else {
            return
        }
        
        // Clear current photos and update selection immediately
        selectedAlbumID = albumID
        photoItems = []
        
        let assets = await photoLibrary.fetchPhotos(from: album)
        var items: [PhotoItem] = []
        
        for asset in assets {
            var item = PhotoItem(asset: asset)
            // Load date immediately, location will be loaded lazily
            item.line1 = EXIFHelper.formatDate(for: asset)
            item.line2 = ""  // Custom text (empty by default)
            items.append(item)
        }
        
        photoItems = items
        
        // Load locations in background after photos are displayed
        Task {
            await loadLocationsForAllPhotos()
        }
    }
    
    func loadThumbnail(for asset: PHAsset) async -> NSImage? {
        let cacheKey = asset.localIdentifier
        
        if let cachedImage = thumbnailCache[cacheKey] {
            return cachedImage
        }
        
        let thumbnail = await photoLibrary.requestThumbnail(for: asset, targetSize: CGSize(width: 200, height: 200))
        
        if let thumbnail = thumbnail {
            thumbnailCache[cacheKey] = thumbnail
        }
        
        return thumbnail
    }
    
    func clearThumbnailCache() {
        thumbnailCache.removeAll()
    }
    
    // MARK: - Location Loading
    
    func loadLocationForPhoto(_ item: PhotoItem) async {
        guard let index = photoItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Skip if line1 has been manually edited
        if photoItems[index].isLine1ManuallyEdited {
            return
        }
        
        let dateString = EXIFHelper.formatDate(for: item.asset)
        var updatedItem = photoItems[index]
        
        if let location = item.asset.location {
            let locationString = await Geo.reverseGeocode(location: location)
            if !locationString.isEmpty {
                updatedItem.line1 = "\(dateString) — \(locationString)"
            } else {
                updatedItem.line1 = dateString
            }
        } else {
            updatedItem.line1 = dateString
        }
        
        await MainActor.run {
            if index < photoItems.count {
                photoItems[index] = updatedItem
            }
        }
    }
    
    func loadLocationsForAllPhotos() async {
        for item in photoItems {
            await loadLocationForPhoto(item)
            // Small delay to avoid overwhelming the geocoding service
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    // MARK: - Selection Management
    
    var selectedItems: [PhotoItem] {
        photoItems.filter { $0.isSelected }
    }
    
    var selectedCount: Int {
        photoItems.filter { $0.isSelected }.count
    }
    
    var allSelected: Bool {
        !photoItems.isEmpty && photoItems.allSatisfy { $0.isSelected }
    }
    
    func toggleSelection(for item: PhotoItem) {
        if let index = photoItems.firstIndex(where: { $0.id == item.id }) {
            photoItems[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        for index in photoItems.indices {
            photoItems[index].isSelected = true
        }
    }
    
    func clearSelection() {
        for index in photoItems.indices {
            photoItems[index].isSelected = false
        }
    }
    
    func selectionIndex(for item: PhotoItem) -> Int? {
        let selectedIndices = photoItems.enumerated().compactMap { index, photoItem in
            photoItem.isSelected ? index : nil
        }
        if let itemIndex = photoItems.firstIndex(where: { $0.id == item.id }),
           let selectionPosition = selectedIndices.firstIndex(of: itemIndex) {
            return selectionPosition + 1
        }
        return nil
    }
    
    // MARK: - Focus Management
    
    func setFocusedItem(_ item: PhotoItem) {
        focusedItem = item
        
        // Load location for this item if not already loaded
        Task {
            await loadLocationForPhoto(item)
        }
    }
    
    func resetLine1ManualEdit(for item: PhotoItem) {
        guard let index = photoItems.firstIndex(where: { $0.id == item.id }) else { return }
        photoItems[index].isLine1ManuallyEdited = false
        
        // Reload location data after resetting the flag
        Task {
            await loadLocationForPhoto(item)
        }
    }
    
    func updateFocusedItem() {
        // Update focused item text when it changes
        if let focused = focusedItem,
           let index = photoItems.firstIndex(where: { $0.id == focused.id }) {
            focusedItem = photoItems[index]
        }
    }
    
    // MARK: - Export functionality
    func exportSelectedPhotos(to url: URL) async {
        for (index, item) in selectedItems.enumerated() {
            // Ensure location data is loaded before exporting
            await loadLocationForPhoto(item)
            
            // Get the updated item with location data
            guard let updatedIndex = photoItems.firstIndex(where: { $0.id == item.id }) else {
                print("Failed to find updated item for index \(index)")
                continue
            }
            let updatedItem = photoItems[updatedIndex]
            
            guard let fullImage = await photoLibrary.requestFullResolutionImage(for: item.asset) else {
                print("Failed to load image for item \(index)")
                continue
            }
            
            // Create fonts for export (full size) using the same approach as ContentView
            let line1Font = NSFont(name: typographySettings.line1FontName, size: typographySettings.line1Size) ?? NSFont.systemFont(ofSize: typographySettings.line1Size)
            let line2Font = NSFont(name: typographySettings.line2FontName, size: typographySettings.line2Size) ?? NSFont.systemFont(ofSize: typographySettings.line2Size)
            
            guard let polaroid = PolaroidRenderer.renderPolaroidFreePrints(
                image: fullImage,
                line1: updatedItem.line1,
                line2: updatedItem.line2,
                exportWidth: 1800, // Full export resolution
                outerMargin: 72,
                bottomBand: 340,
                cardCorner: 28,
                photoCorner: 16,
                line1Font: line1Font,
                line2Font: line2Font,
                textColor: typographySettings.textColor,
                line1Kern: typographySettings.line1Kern,
                line2Kern: typographySettings.line2Kern,
                line2Baseline: typographySettings.line2Baseline
            ) else {
                print("Failed to render polaroid for item \(index)")
                continue
            }
            
            // Create filename
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: item.asset.creationDate ?? Date())
            let filename = "polaroid_\(dateString)_\(index + 1).jpg"
            let fileURL = url.appendingPathComponent(filename)
            
            // Save as JPEG
            if let tiffData = polaroid.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.9]) {
                try? jpegData.write(to: fileURL)
                print("Exported: \(filename)")
            }
        }
    }
}