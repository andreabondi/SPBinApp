//
//  utils.swift
//  SPBinApp
//
//  Created by Bondi, Andrea on 30/08/2018.
//  Copyright © 2018 Bondi, Andrea. All rights reserved.
//

import Foundation

// Identify which payment flow to initiate
enum Payment {
    case paypal
    case cards
}

// Parse query strings
func getQueryStringParameter(url: String, param: String) -> String? {
    guard let url = URLComponents(string: url) else { return nil }
    return url.queryItems?.first(where: { $0.name == param })?.value
}

// Uniquely identify the notifications to send
extension Notification.Name {
    static let complete = Notification.Name("complete")
    static let cancel = Notification.Name("cancel")
}
