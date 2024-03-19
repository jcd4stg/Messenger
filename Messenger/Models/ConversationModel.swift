//
//  ConversationModel.swift
//  Messenger
//
//  Created by lynnguyen on 20/03/2024.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    var otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
