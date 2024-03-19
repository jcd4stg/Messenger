//
//  StorageManager.swift
//  Messenger
//
//  Created by lynnguyen on 24/02/2024.
//

import Foundation
import FirebaseStorage

// Allow you to get, fetch, and upload files to firebase storage
final class StorageManager {
    
    static let shared = StorageManager()
    
    private init() {}
    
    private let storage = Storage.storage().reference()
    
    /*
     /images/duyhuy-871-gmail-com_profile_picture.png
     */
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
        case failedToCastUrlToData
    }
    
    /// Upload picture to firebase storage and return completion with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] data, error in
            guard let _ = data, error == nil else {
                // failed
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("images/\(fileName)").downloadURL { url, error in
                guard let url = url, error == nil else {
                    print("Failed to get download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download url returned: \(urlString)")
                completion(.success(urlString))
            }
        }
        
    }
    
    public func downloadURL(for path: String, completion: @escaping ((Result<URL, Error>) -> Void)) {
        let reference = storage.child(path)
        reference.downloadURL { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            completion(.success(url))
        }
    }
    
    // Upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("messages_images/\(fileName)").putData(data, metadata: nil) { [weak self] data, error in
            guard let _ = data, error == nil else {
                // failed
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("messages_images/\(fileName)").downloadURL { url, error in
                guard let url = url, error == nil else {
                    print("Failed to get download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download url returned: \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    // Upload video that will be sent in a conversation message
    public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
        
        guard let videoData = NSData(contentsOf: fileUrl) as? Data else {
            completion(.failure(StorageErrors.failedToCastUrlToData))
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"

        storage.child("messages_videos/\(fileName)").putData(videoData, metadata: metadata) { [weak self] data, error in
            guard let _ = data, error == nil else {
                // failed
                print("Failed to upload video file to firebas")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("messages_videos/\(fileName)").downloadURL { url, error in
                guard let url = url, error == nil else {
                    print("Failed to get download URL")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download url returned: \(urlString)")
                completion(.success(urlString))
            }
        }
    }
}
