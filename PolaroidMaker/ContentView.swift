//
//  ContentView.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var isExporting = false
    
    var body: some View {
        if viewModel.authorizationStatus == .authorized || viewModel.authorizationStatus == .limited {
            HStack(spacing: 0) {
                SidebarView(viewModel: viewModel)
                    .frame(minWidth: 250, maxWidth: 400)
                
                Divider()
                
                MainContentView(viewModel: viewModel, isExporting: $isExporting)
            }
            .task {
                await viewModel.loadAlbums()
            }
        } else {
            PhotoAccessView(viewModel: viewModel)
        }
    }
}

// MARK: - Main Content View (Preview on top, thumbnails at bottom)
struct MainContentView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var isExporting: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar with typography controls
            TopToolbarView(viewModel: viewModel, isExporting: $isExporting)
            
            Divider()
            
            if viewModel.photoItems.isEmpty {
                ContentUnavailableView("No Photos", 
                                     systemImage: "photo",
                                     description: Text("Select an album from the sidebar to view photos"))
            } else {
                VStack(spacing: 0) {
                    // Preview area (top)
                    PreviewAreaView(viewModel: viewModel)
                        .frame(maxHeight: .infinity)
                    
                    Divider()
                    
                    // Thumbnail grid (bottom)
                    ThumbnailGridAreaView(viewModel: viewModel)
                        .frame(minHeight: 200, idealHeight: 300, maxHeight: 400)
                }
            }
        }
        .onAppear {
            viewModel.clearSelection()
        }
        .onChange(of: viewModel.selectedAlbumID) { _, _ in
            viewModel.clearSelection()
        }
    }
}

// MARK: - Top Toolbar with Typography Controls
struct TopToolbarView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var isExporting: Bool
    @State private var showTypographyControls = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Left side - Selection controls
                HStack(spacing: 16) {
                    Button(viewModel.allSelected ? "Clear" : "Select All") {
                        if viewModel.allSelected {
                            viewModel.clearSelection()
                        } else {
                            viewModel.selectAll()
                        }
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    
                    if viewModel.selectedCount > 0 {
                        Text("Selected: \(viewModel.selectedCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - Typography and export controls
                HStack(spacing: 16) {
                    Button("Typography") {
                        showTypographyControls.toggle()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        exportSelectedPhotos()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("Export Selected")
                        }
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            
            if showTypographyControls {
                Divider()
                TypographyControlsView(viewModel: viewModel)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .onKeyDown(key: .escape) {
            viewModel.clearSelection()
            return true
        }
    }
    
    private func exportSelectedPhotos() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Export Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            isExporting = true
            
            Task {
                await viewModel.exportSelectedPhotos(to: url)
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Typography Controls
struct TypographyControlsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 32) {
                // Line 1 Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Line 1 (Date/Location)")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Font", selection: $viewModel.typographySettings.line1FontName) {
                            ForEach(TypographySettings.line1FontOptions, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 200)
                        
                        HStack {
                            Text("Size")
                            Slider(value: $viewModel.typographySettings.line1Size, in: 20...80)
                            Text("\(Int(viewModel.typographySettings.line1Size))")
                                .frame(width: 30, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("Tracking")
                            Slider(value: $viewModel.typographySettings.line1Kern, in: 0...2.0)
                            Text(String(format: "%.1f", viewModel.typographySettings.line1Kern))
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                
                // Line 2 Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Line 2 (Custom Text)")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Font", selection: $viewModel.typographySettings.line2FontName) {
                            ForEach(TypographySettings.line2FontOptions, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 200)
                        
                        HStack {
                            Text("Size")
                            Slider(value: $viewModel.typographySettings.line2Size, in: 20...80)
                            Text("\(Int(viewModel.typographySettings.line2Size))")
                                .frame(width: 30, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("Tracking")
                            Slider(value: $viewModel.typographySettings.line2Kern, in: 0...2.0)
                            Text(String(format: "%.1f", viewModel.typographySettings.line2Kern))
                                .frame(width: 30, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("Baseline")
                            Slider(value: $viewModel.typographySettings.line2Baseline, in: -10...10)
                            Text(String(format: "%.0f", viewModel.typographySettings.line2Baseline))
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                
                // Color Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Color")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(TypographySettings.colorOptions, id: \.0) { colorName, color in
                            Button {
                                viewModel.typographySettings.textColor = color
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(color))
                                        .frame(width: 16, height: 16)
                                    Text(colorName)
                                    Spacer()
                                    if viewModel.typographySettings.textColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.typographySettings.textColor == color ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview Area (Top half)
struct PreviewAreaView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Album title with focused thumbnail
            if let albumID = viewModel.selectedAlbumID,
               let album = viewModel.albums.first(where: { $0.localIdentifier == albumID }) {
                PreviewTitleView(
                    albumTitle: album.localizedTitle ?? "Untitled",
                    focusedItem: viewModel.focusedItem,
                    viewModel: viewModel
                )
            }
            
            // Main preview card
            if let focusedItem = viewModel.focusedItem {
                PreviewCardView(item: focusedItem, viewModel: viewModel)
            } else if let firstSelected = viewModel.selectedItems.first {
                PreviewCardView(item: firstSelected, viewModel: viewModel)
            } else {
                Text("Select a photo to see preview")
                    .foregroundColor(.secondary)
                    .font(.title2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}

// MARK: - Preview Title with Focused Thumbnail
struct PreviewTitleView: View {
    let albumTitle: String
    let focusedItem: PhotoItem?
    @ObservedObject var viewModel: LibraryViewModel
    @State private var focusedThumbnail: NSImage?
    
    var body: some View {
        HStack {
            Text(albumTitle)
                .font(.title2)
                .fontWeight(.medium)
            
            if let focusedItem = focusedItem {
                Group {
                    if let thumbnail = focusedThumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 48, height: 48)
                    }
                }
                .task(id: focusedItem.id) {
                    focusedThumbnail = await viewModel.loadThumbnail(for: focusedItem.asset)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview Card
struct PreviewCardView: View {
    let item: PhotoItem
    @ObservedObject var viewModel: LibraryViewModel
    @State private var fullImage: NSImage?
    @State private var previewImage: NSImage?
    @State private var isGeneratingPreview = false
    
    // Computed property that creates a settings hash for reactive updates
    private var settingsHash: Int {
        guard let currentItem = viewModel.photoItems.first(where: { $0.id == item.id }) else {
            return 0
        }
        return viewModel.typographySettings.settingsHash(with: currentItem.line1, line2: currentItem.line2)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Preview image - reactive to all typography settings and caption text
            Group {
                if let previewImage = previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 900, maxHeight: .infinity)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: 900, maxHeight: .infinity)
                        .overlay {
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                }
            }
            
            // Caption editing
            VStack(spacing: 8) {
                if let itemIndex = viewModel.photoItems.firstIndex(where: { $0.id == item.id }) {
                    TextField("Date & Location", text: $viewModel.photoItems[itemIndex].line1, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 400)
                        .lineLimit(1...2)
                        .font(.system(size: 14))
                        .onChange(of: viewModel.photoItems[itemIndex].line1) { _, _ in
                            // Mark line1 as manually edited when user changes it
                            viewModel.photoItems[itemIndex].isLine1ManuallyEdited = true
                        }
                    
                    TextField("Custom Text", text: $viewModel.photoItems[itemIndex].line2, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 400)
                        .lineLimit(1...3)
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .task(id: item.id) {
            await loadFullImage()
        }
        .task(id: settingsHash) {
            await generatePreviewSafely()
        }
    }
    
    private func loadFullImage() async {
        fullImage = await PhotoLibrary.shared.requestFullResolutionImage(for: item.asset)
        await generatePreviewSafely()
    }
    
    @MainActor
    private func generatePreviewSafely() async {
        guard let fullImage = fullImage else { return }
        guard !isGeneratingPreview else { return } // Prevent concurrent generation
        
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }
        
        // Get current text from viewModel to ensure we have the latest changes
        guard let currentItem = viewModel.photoItems.first(where: { $0.id == item.id }) else { return }
        
        // Generate preview synchronously but safely (avoiding Task.detached issues)
        let line1Font = Fonts.loadFont(family: viewModel.typographySettings.line1FontName, 
                                     size: viewModel.typographySettings.line1Size * 0.5)
        let line2Font = Fonts.loadFont(family: viewModel.typographySettings.line2FontName, 
                                     size: viewModel.typographySettings.line2Size * 0.5)
        
        // Render preview safely on main thread (images are small at 900px)
        let newPreviewImage = PolaroidRenderer.renderPolaroidFreePrints(
            image: fullImage,
            line1: currentItem.line1,
            line2: currentItem.line2,
            exportWidth: 900,
            outerMargin: 36, // Scaled down from 72 for preview
            bottomBand: 170, // Scaled down from 340 for preview
            cardCorner: 14,  // Scaled down from 28 for preview
            photoCorner: 8,  // Scaled down from 16 for preview
            line1Font: line1Font,
            line2Font: line2Font,
            textColor: viewModel.typographySettings.textColor,
            line1Kern: viewModel.typographySettings.line1Kern,
            line2Kern: viewModel.typographySettings.line2Kern,
            line2Baseline: viewModel.typographySettings.line2Baseline
        )
        
        previewImage = newPreviewImage
    }
}

// MARK: - Thumbnail Grid Area (Bottom half)
struct ThumbnailGridAreaView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.photoItems) { item in
                    PhotoGridCell(item: item, viewModel: viewModel)
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Photo Grid Cell
struct PhotoGridCell: View {
    let item: PhotoItem
    @ObservedObject var viewModel: LibraryViewModel
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail image
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Selection overlay
            if item.isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 120, height: 120)
            }
            
            // Focus indicator
            if viewModel.focusedItem?.id == item.id {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 120, height: 120)
            }
            
            // Selection badge
            SelectionBadge(
                isSelected: item.isSelected,
                index: viewModel.selectionIndex(for: item)
            )
            .padding(8)
        }
        .onTapGesture {
            viewModel.toggleSelection(for: item)
            viewModel.setFocusedItem(item)
        }
        .task {
            if thumbnail == nil {
                thumbnail = await viewModel.loadThumbnail(for: item.asset)
            }
        }
    }
}

// MARK: - Selection Badge
struct SelectionBadge: View {
    let isSelected: Bool
    let index: Int?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 24, height: 24)
            
            if isSelected {
                if let index = index {
                    Text("\(index)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Albums")
                .font(.headline)
                .padding()
            
            List(viewModel.albums, id: \.localIdentifier) { album in
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.secondary)
                    
                    Text(album.localizedTitle ?? "Untitled")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(album.estimatedAssetCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        await viewModel.loadPhotosFromAlbum(album.localIdentifier)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.selectedAlbumID == album.localIdentifier ? 
                           Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            }
            .listStyle(PlainListStyle())
        }
    }
}

// MARK: - Photo Access View
struct PhotoAccessView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 64))
            
            Text("PolaroidMaker")
                .font(.largeTitle)
            
            Text("This app needs access to your Photos to create polaroids.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Grant Photos Access") {
                Task {
                    await viewModel.requestPhotoAccess()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Key Handling Extension
extension View {
    func onKeyDown(key: KeyEquivalent, action: @escaping () -> Bool) -> some View {
        self.background(KeyEventHandling(key: key, action: action))
    }
}

struct KeyEventHandling: NSViewRepresentable {
    let key: KeyEquivalent
    let action: () -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.key = key
        view.action = action
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyEventView: NSView {
    var key: KeyEquivalent = KeyEquivalent("a")
    var action: (() -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            if action?() == true {
                return
            }
        }
        super.keyDown(with: event)
    }
}

#Preview {
    ContentView()
}