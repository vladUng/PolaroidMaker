//
//  PhotoLibrary.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import Photos
import AppKit
import CoreLocation

class PhotoLibrary: NSObject, ObservableObject {
    static let shared = PhotoLibrary()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status == .authorized || status == .limited
    }
    
    func fetchAlbums() async -> [PHAssetCollection] {
        return await withCheckedContinuation { continuation in
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                continuation.resume(returning: [])
                return
            }
            
            var albums: [PHAssetCollection] = []
            
            let smartAlbumsResult = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            )
            
            let userAlbumsResult = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .albumRegular,
                options: nil
            )
            
            smartAlbumsResult.enumerateObjects { collection, _, _ in
                if collection.estimatedAssetCount > 0 {
                    albums.append(collection)
                }
            }
            
            userAlbumsResult.enumerateObjects { collection, _, _ in
                if collection.estimatedAssetCount > 0 {
                    albums.append(collection)
                }
            }
            
            let sortedAlbums = albums.sorted { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
            continuation.resume(returning: sortedAlbums)
        }
    }
    
    func fetchPhotos(from album: PHAssetCollection) async -> [PHAsset] {
        return await withCheckedContinuation { continuation in
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let assets = PHAsset.fetchAssets(in: album, options: options)
            var photos: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                photos.append(asset)
            }
            
            continuation.resume(returning: photos)
        }
    }
    
    func requestThumbnail(for asset: PHAsset, targetSize: CGSize = CGSize(width: 400, height: 400)) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func requestFullResolutionImage(for asset: PHAsset) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
