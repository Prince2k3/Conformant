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
