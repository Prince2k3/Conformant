//
//  FileViolationStore.swift
//  Conformant
//
//  Copyright © 2025 Prince Ugwuh. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// Implementation of ViolationStore that uses a JSON file
public class FileViolationStore: ViolationStore {
    private let filePath: String
    
    /// Creates a new file-based violation store
    /// - Parameter filePath: The path to the JSON file where violations will be stored
    public init(filePath: String) {
        self.filePath = filePath
    }
    
    public func loadViolations() -> [StoredViolation] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            return try JSONDecoder().decode([StoredViolation].self, from: data)
        } catch {
            print("Error loading violations: \(error)")
            return []
        }
    }
    
    public func saveViolations(_ violations: [StoredViolation]) {
        do {
            let data = try JSONEncoder().encode(violations)
            try data.write(to: URL(fileURLWithPath: filePath))
        } catch {
            print("Error saving violations: \(error)")
        }
    }
}
