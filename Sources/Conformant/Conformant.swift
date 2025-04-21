import Foundation

/// Represents a collection of Swift files to analyze
public struct Conformant {
    private let swiftFiles: [SwiftFile]

    private init(swiftFiles: [SwiftFile]) {
        self.swiftFiles = swiftFiles
    }

    public static func scopeFromProject(_ projectPath: String = FileManager.default.currentDirectoryPath) -> Conformant {
        let fileManager = FileManager.default
        let parser = SwiftSyntaxParser()
        var swiftFiles: [SwiftFile] = []

        // Helper function to recursively scan directories
        func scanDirectory(_ directoryPath: String) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)

                for item in contents {
                    let itemPath = (directoryPath as NSString).appendingPathComponent(item)
                    var isDirectory: ObjCBool = false

                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            // Skip common directories that shouldn't be analyzed
                            if !shouldSkipDirectory(item) {
                                scanDirectory(itemPath)
                            }
                        } else if item.hasSuffix(".swift") {
                            // Parse Swift file and add to scope
                            do {
                                let swiftFile = try parser.parseFile(path: itemPath)
                                swiftFiles.append(swiftFile)
                            } catch {
                                print("Error parsing Swift file at \(itemPath): \(error)")
                            }
                        }
                    }
                }
            } catch {
                print("Error scanning directory \(directoryPath): \(error)")
            }
        }

        // Start scanning from the project root
        scanDirectory(projectPath)

        return Conformant(swiftFiles: swiftFiles)
    }

    private static func shouldSkipDirectory(_ directoryName: String) -> Bool {
        // Common directories to skip
        let directoriesToSkip = [
            ".git",           // Git directory
            ".build",         // Swift build directory
            "Pods",           // CocoaPods
            "Carthage",       // Carthage
            "DerivedData",    // Xcode derived data
            ".xcodeproj",     // Xcode project files
            ".xcworkspace",   // Xcode workspace
            ".playground",    // Swift playgrounds
            "node_modules",   // Node.js modules
            ".github",        // GitHub configuration
            ".gitlab",        // GitLab configuration
            "fastlane",       // Fastlane directory
            "vendor",         // Vendor dependencies
            "Frameworks",     // Frameworks directory that might contain compiled binaries
            "Products"        // Products directory
        ]
        
        // Skip hidden directories (those starting with .)
        if directoryName.hasPrefix(".") {
            return true
        }
        
        // Skip directories in the skip list
        return directoriesToSkip.contains { directoryName.contains($0) }
    }

    public static func scopeFromDirectory(_ path: String) -> Conformant {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: path)
        var swiftFileURLs: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil, // Can add [.isRegularFileKey] for efficiency
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error -> Bool in
                print("Directory enumerator error at \(url): \(error)")
                return true
            }
        ) else {
            print("Error: Could not create directory enumerator for path: \(path)")
            return Conformant(swiftFiles: [])
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                // Optional: Check if it's a regular file if not done via keys
                // var isRegularFile: ObjCBool = false
                // if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isRegularFile) && isRegularFile.boolValue {
                swiftFileURLs.append(fileURL)
                // }
            }
        }

        if swiftFileURLs.isEmpty {
            print("Warning: No Swift files found recursively in directory: \(path)")
            if !fileManager.fileExists(atPath: path) {
                print("Error: Directory path does not exist: \(path)")
            }
            return Conformant(swiftFiles: [])
        }

        let parser = SwiftSyntaxParser()
        let swiftFiles = swiftFileURLs.compactMap { url -> SwiftFile? in
            do {
                return try parser.parseFile(path: url.path)
            } catch {
                print("Error parsing file \(url.path): \(error)")
                return nil
            }
        }

        return Conformant(swiftFiles: swiftFiles)
    }

    public static func scopeFromFile(path: String) -> Conformant {
        do {
            let parser = SwiftSyntaxParser()
            let file = try parser.parseFile(path: path)
            return Conformant(swiftFiles: [file])
        } catch {
            print("Error parsing file \(path): \(error)")
            return Conformant(swiftFiles: [])
        }
    }

    // Query methods

    public func files() -> [SwiftFile] {
        return swiftFiles
    }

    /// Returns all import declarations in the scope
    public func imports() -> [SwiftImportDeclaration] {
        return files().flatMap { $0.imports }
    }

    /// Returns all imports of a specific module
    public func importsOf(_ module: String) -> [SwiftImportDeclaration] {
        return imports().filter { $0.isImportOf(module) }
    }

    /// Checks if any file in the scope imports the specified module
    public func hasImport(of module: String) -> Bool {
        return imports().contains { $0.isImportOf(module) }
    }

    public func classes() -> [SwiftClassDeclaration] {
        return files().flatMap { $0.classes }
    }

    public func structs() -> [SwiftStructDeclaration] {
        return files().flatMap { $0.structs }
    }

    public func protocols() -> [SwiftProtocolDeclaration] {
        return files().flatMap { $0.protocols }
    }

    public func extensions() -> [SwiftExtensionDeclaration] {
        return files().flatMap { $0.extensions }
    }

    public func functions() -> [SwiftFunctionDeclaration] {
        return files().flatMap { $0.functions }
    }

    public func properties() -> [SwiftPropertyDeclaration] {
        return files().flatMap { $0.properties }
    }

    public func enums() -> [SwiftEnumDeclaration] {
        return files().flatMap { $0.enums }
    }

//    declaration → import-declaration
//    declaration → constant-declaration // missing
//    declaration → variable-declaration
//    declaration → typealias-declaration // missing
//    declaration → function-declaration
//    declaration → enum-declaration
//    declaration → struct-declaration
//    declaration → class-declaration
//    declaration → actor-declaration // missing
//    declaration → protocol-declaration
//    declaration → initializer-declaration // missing
//    declaration → deinitializer-declaration // missing
//    declaration → extension-declaration
//    declaration → subscript-declaration // missing
//    declaration → macro-declaration // missing
//    declaration → operator-declaration // missing
//    declaration → precedence-group-declaration // missing

    public func declarations() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: imports().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: functions().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: properties().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func types() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func typesAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: protocols().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func classesAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: classes().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func structsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: structs().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }

    public func enumsAndExtensions() -> [AnySwiftDeclaration] {
        var declarations: [AnySwiftDeclaration] = []
        declarations.append(contentsOf: enums().map(AnySwiftDeclaration.init))
        declarations.append(contentsOf: extensions().map(AnySwiftDeclaration.init))
        return declarations
    }
}
