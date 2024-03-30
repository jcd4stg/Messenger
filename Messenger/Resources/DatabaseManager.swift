//
//  DatabaseManager.swift
//  Messenger
//
//  Created by lynnguyen on 16/02/2024.
//

import Foundation
import FirebaseCore
import MessageKit
import CoreLocation
import Firebase

///  Manager object to read and write data to real time firebase database
final class DatabaseManager {
    
    // Shared instance of class
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
        
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    
    /// Returns dictionary node at child path
    public func getDataFor(path: String, completion: @escaping((Result<Any, Error>) -> Void)) {
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
}

// MARK: - Account Management
extension DatabaseManager {
    
    /// Check if user exists for given email
    /// Parameters
    /// - `email`:               Target email to be checked
    /// - `completion`:    Async closure to return with email
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
        
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping ((Bool) -> Void)) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ]) { [weak self] error, _ in
            
            guard let strongSelf = self else {
                return
            }
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var userCollection = snapshot.value as? [[String: String]] {
                    // append to user dictionary
                    let newElement: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]

                    userCollection.append(contentsOf: newElement)
                    
                    strongSelf.database.child("users").setValue(userCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }

                    
                } else {
                    // create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    
                    strongSelf.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
        }   
    }
    
    /*
     users => [
        [
            "name": email,
            "safe_email":
        ],
        [
            "name": email,
            "safe_email":
        ]
     ]
     */
    
    /// Gets all users from database
    public func getAllUsers(completion: @escaping ((Result<[[String: String]], Error>) -> Void)) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
        
        public var localizedDescription: String {
            switch self {
            case .failedToFetch:
                return "This means blah failed"
            }
        }
    }
    
}

// MARK: - Sending messages / conversations
extension DatabaseManager {
    
    /*
     
     "sdsa" {
        "messages": [
            {
                "id": String,
                "type": text, photo, video,
                "content": String,
                "date": Date(),
                "sender_email": String,
                "isRead": true/false
            }
        ]
     }
        conversations => [
        [
            "conversation_Id": "sdsa",
            "other_user_email":,
            "latest_message": => {
                "date": Date(),
                "latest_message": "message",
                "is_read": true/false
            }
        ],
        
     ]
     */

    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping ((Bool) -> Void)) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
            let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let reference = database.child("\(safeEmail)")
        
        reference.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
               
            let recipent_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            //update recipent conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    // append
                    conversations.append(recipent_newConversationData)
                    
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                    
                } else {
                    // create
                    
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipent_newConversationData])
                }
            }
            
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                reference.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(
                        name: name,
                        conversationID: conversationId,
                        firstMessage: firstMessage,
                        completion: completion)
                }

            } else {
                // conversatation array does not exist
                // create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                reference.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(
                        name: name,
                        conversationID: conversationId,
                        firstMessage: firstMessage,
                        completion: completion)
                }
            }
        }
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping ((Bool) -> Void)) {
//        "sdsa" {
//           "messages": [
//               {
//                   "id": String,
//                   "type": text, photo, video,
//                   "content": String,
//                   "date": Date(),
//                   "sender_email": String,
//                   "isRead": true/false
//               }
//           ]
//        }
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return 
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)

        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)

        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("Adding conversation: \(conversationID)")
        
        database.child("\(conversationID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
        
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping ((Result<[Conversation], Error>) -> Void)) {
        
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap ({ dictionary in
                
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            
            completion(.success(conversations))
        })
    
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping ((Result<[Message], Error>) -> Void)) {
        
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            print("get for conversations")
            
            let messages: [Message] = value.compactMap ({ dictionary in
                
                guard let name = dictionary["name"] as? String,
                      //let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as?  String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                    return nil
                }
                
                var kind: MessageKind?
                
                if type == "photo" {
                    // photo
                    guard let imageUrl = URL(string: content),
                          let placeholder = UIImage(systemName: "plus") else {
                        return nil
                    }
                    
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .photo(media)
                    
                } 
                else if type == "video" {
                    guard let videoUrl = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder") else {
                        return nil
                    }
                    
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .video(media)
                }
                else if type == "location" {
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longtitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                        return nil
                    }
                    
                    print("Rendering location: long=\(longtitude) | lat=\(latitude)")
                    let location = Location(location: CLLocation(latitude: latitude,
                                                                 longitude: longtitude),
                                            size: CGSize(width: 300, height: 300))
                    
                    kind = .location(location)
                }
                else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: finalKind)
            })
            
            print("Messgaes returned: \(messages)")
            completion(.success(messages))
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversationId: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping ((Bool) -> Void)) {
        // add new message to messages
        // update sender latest message
        // update recipient latest message
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") else {
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversationId)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)

            var message = ""
            
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
        

            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversationId)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryCurrentEmailConversation = [[String: Any]]()
                    
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "message": message,
                        "is_read": false
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        
                        var targetConversation: [String: Any]?
                        
                        var position = 0
                        
                        for conversationDictionary in currentUserConversations {
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversationId {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                        
                            currentUserConversations[position] = targetConversation
                            
                            databaseEntryCurrentEmailConversation = currentUserConversations
                        }
                        else {
                            let newConversationData: [String: Any] = [
                                "id": conversationId,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryCurrentEmailConversation = currentUserConversations
                        }
        
                    }
                    else {
                        
                        let newConversationData: [String: Any] = [
                            "id": conversationId,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        
                        databaseEntryCurrentEmailConversation = [
                            newConversationData
                        ]
                    }
                    
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryCurrentEmailConversation) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        //  update latest message for recipient user
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            var databaseEntryOtherUserEmailConversation = [[String: Any]]()

                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "message": message,
                                "is_read": false
                            ]
                            
                            if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                
                                var targetConversation: [String: Any]?
                                
                                var position = 0
                                
                                for conversationDictionary in otherUserConversations {
                                    if let currentId = conversationDictionary["id"] as? String, currentId == conversationId {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    
                                    otherUserConversations[position] = targetConversation
                                    
                                    databaseEntryOtherUserEmailConversation = otherUserConversations
                                }
                                else {
                                    // failed to find in current collection
                                    let recipent_newConversationData: [String: Any] = [
                                        "id": conversationId,
                                        "other_user_email": currentEmail,
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    databaseEntryOtherUserEmailConversation.append(recipent_newConversationData)
                                }
                            }
                            else {
                                // current collection does not exist
                                let recipent_newConversationData: [String: Any] = [
                                    "id": conversationId,
                                    "other_user_email": currentEmail,
                                    "name": currentName,
                                    "latest_message": updatedValue
                                ]
                                
                                databaseEntryOtherUserEmailConversation = [
                                    recipent_newConversationData
                                ]
                            }
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryOtherUserEmailConversation) { error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                
                                // update latest message for recepient user
                                
                                strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                                    var databaseEntryOtherUserEmailConversation = [[String: Any]]()

                                    let updatedValue: [String: Any] = [
                                        "date": dateString,
                                        "message": message,
                                        "is_read": false
                                    ]
                                    
                                    if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                        
                                        var targetConversation: [String: Any]?
                                        
                                        var position = 0
                                        
                                        for conversationDictionary in otherUserConversations {
                                            if let currentId = conversationDictionary["id"] as? String, currentId == conversationId {
                                                targetConversation = conversationDictionary
                                                break
                                            }
                                            position += 1
                                        }
                                        
                                        if var targetConversation = targetConversation {
                                            targetConversation["latest_message"] = updatedValue
                                            
                                            otherUserConversations[position] = targetConversation
                                            
                                            databaseEntryOtherUserEmailConversation = otherUserConversations
                                        }
                                        else {
                                            // failed to find in current collection
                                            let recipent_newConversationData: [String: Any] = [
                                                "id": conversationId,
                                                "other_user_email": currentEmail,
                                                "name": currentName,
                                                "latest_message": updatedValue
                                            ]
                                            databaseEntryOtherUserEmailConversation.append(recipent_newConversationData)
                                        }
                                    }
                                    else {
                                        // current collection does not exist
                                        let recipent_newConversationData: [String: Any] = [
                                            "id": conversationId,
                                            "other_user_email": currentEmail,
                                            "name": currentName,
                                            "latest_message": updatedValue
                                        ]
                                        
                                        databaseEntryOtherUserEmailConversation = [
                                            recipent_newConversationData
                                        ]
                                    }
                                    
                                    strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryOtherUserEmailConversation) { error, _ in
                                        guard error == nil else {
                                            completion(false)
                                            return
                                        }
                                        completion(true)
                                    }
                                })
        
                            }
                        })
                    }
                })
            }
        })
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping ((Bool) -> Void)) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print("Deleting conversation with id: \(conversationId)")
        
        // get all conversations for current user
        // delete conversation in collection with target id
        // reset those conversations for the user in database
        
        let ref = database.child("\(safeEmail)/conversations")
    
        ref.observeSingleEvent(of: .value, with: { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                
                var positionToRemove = 0
                
                for conversation in conversations {
                    if let id = conversation["id"] as? String, id == conversationId {
                        print("found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                
                conversations.remove(at: positionToRemove)
                
                ref.setValue(conversations) { error, _ in
                    guard error == nil else {
                        completion(false)
                        print("failed to write new conversation array")
                        return
                    }
                    print("Deleted conversation")
                    completion(true)
                }
            }
        })
    }
    
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping ((Result<String, Error>) -> Void)) {
        let safeRecepientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        
        database.child("\(safeRecepientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            // iterate and find conversation with target sender
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // get id
                guard let id = conversation["id"] as? String else {
                    return
                }
                completion(.success(id))
                return
            }
            
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
    
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
