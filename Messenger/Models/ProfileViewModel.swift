//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by lynnguyen on 20/03/2024.
//

import Foundation

enum ProfileViewModelType {
    case info
    case logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handle: (() -> Void)?
}
