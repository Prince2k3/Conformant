import Foundation

/// Represents a Swift source file
public struct SwiftFile {
    let path: String
    let imports: [SwiftImportDeclaration]
    let classes: [SwiftClassDeclaration]
    let structs: [SwiftStructDeclaration]
    let protocols: [SwiftProtocolDeclaration]
    let extensions: [SwiftExtensionDeclaration]
    let functions: [SwiftFunctionDeclaration]
    let properties: [SwiftPropertyDeclaration]
    let enums: [SwiftEnumDeclaration]

    var internalDependencies: [SwiftDependency] {
        var deps: [SwiftDependency] = []
        deps.append(contentsOf: classes.flatMap { $0.dependencies })
        deps.append(contentsOf: structs.flatMap { $0.dependencies })
        deps.append(contentsOf: protocols.flatMap { $0.dependencies })
        deps.append(contentsOf: extensions.flatMap { $0.dependencies })
        deps.append(contentsOf: functions.flatMap { $0.dependencies })
        deps.append(contentsOf: properties.flatMap { $0.dependencies })
        deps.append(contentsOf: enums.flatMap { $0.dependencies })
        return deps
    }

    /// Dependencies originating from import statements in this file.
    var importDependencies: [SwiftDependency] {
        return imports.map {
            SwiftDependency(name: $0.name, kind: .import, location: $0.location)
            
            // SwiftDependency(name: $0.fullPath, kind: .import, location: $0.location)
        }
    }
}
