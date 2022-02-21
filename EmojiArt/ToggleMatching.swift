//
//  ToggleMatching.swift
//  EmojiArt
//
//  Created by Eric Kim on 2/21/22.
//

import Foundation

extension Set where Element: Identifiable {
    mutating func toggleMatching(_ element: Element) {
        if let matchingIndex = firstIndex(where: {$0.id == element.id}) {
            remove(at: matchingIndex)
        } else {
            insert(element)
        }
    }
    
    func containsMatching(_ element: Element) -> Bool {
        contains(where: {$0.id == element.id})
    }
}
