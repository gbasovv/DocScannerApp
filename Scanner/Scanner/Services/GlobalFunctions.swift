//
//  GlobalFunctions.swift
//  Scanner
//
//  Created by George on 15.10.21.
//

import UIKit

class GlobalFunctions {
    
    static let shared = GlobalFunctions()
    private init() { }
    
    func showError(withText text: String, label: UILabel) {
        label.text = text
        UIView.animate(withDuration: 5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseInOut, animations: { label.alpha = 1 }) { _ in
            label.alpha = 0
        }
    }
}

enum Warnings {
    static let nameError = "You must name the file"
    static let textError = "If you want to create file, it must contains some text"
    static let success = "File created at temp directory"
    static let createError = "Could't create file because of error: "
}
