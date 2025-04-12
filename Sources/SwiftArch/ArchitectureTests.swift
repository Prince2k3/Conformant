//
//  ArchitectureTests.swift
//  SwiftArch
//
//  Created by Prince Ugwuh on 4/10/25.
//


import Foundation
import XCTest

// MARK: - ArchRule XCTest Integration

extension ArchRule {
    /// Check the rule and throw an XCTest failure if it fails
    /// - Parameter target: The architecture model to check against
    /// - Parameter file: The file where the test is defined
    /// - Parameter line: The line where the test is defined
    public func check(target: SwiftTarget, file: StaticString = #filePath, line: UInt = #line) {
        let result = self.check(target: target)
        
        if !result.passed {
            let failureMessage = buildFailureMessage(result)
            XCTFail(failureMessage, file: file, line: line)
        }
    }
    
    /// Build a detailed failure message for XCTest
    /// - Parameter result: The result of checking the rule
    /// - Returns: A formatted failure message
    private func buildFailureMessage(_ result: RuleCheckResult) -> String {
        var message = "Rule '\(result.ruleDescription)' failed with \(result.violations.count) violations:\n"
        
        for (index, violation) in result.violations.enumerated() {
            message += "\n\(index + 1). \(violation.description)"
            
            if let location = violation.location {
                message += " at \(location.file):\(location.line)"
            }
        }
        
        return message
    }
}

// MARK: - Test Case Extensions

/// Protocol for test cases that verify architecture rules
public protocol ArchitectureTests {
    /// The architecture model to check against
    var architecture: SwiftTarget { get }
}

extension ArchitectureTests {
    /// Check if the given rule is satisfied by the architecture
    /// - Parameter rule: The rule to check
    /// - Parameter file: The file where the test is defined
    /// - Parameter line: The line where the test is defined
    public func assertArchitectureRule(_ rule: ArchRule, file: StaticString = #filePath, line: UInt = #line) {
        rule.check(target: architecture, file: file, line: line)
    }
}

/// Extension for XCTestCase to make it easier to define architecture tests
extension XCTestCase {
    /// Create and check an architecture rule
    /// - Parameter ruleBuilder: Closure that builds the rule to check
    /// - Parameter target: The architecture model to check against
    /// - Parameter file: The file where the test is defined
    /// - Parameter line: The line where the test is defined
    public func assertArchitecture(
        _ ruleBuilder: () -> ArchRule,
        target: SwiftTarget,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rule = ruleBuilder()
        rule.check(target: target, file: file, line: line)
    }
}

// MARK: - Test Configuration

/// Configuration for architecture testing
public struct ArchitectureTestConfig {
    /// Path to the project directory
    public let projectPath: String
    
    /// Module name (if not provided, will use the directory name)
    public let moduleName: String?
    
    /// Create a new configuration
    /// - Parameters:
    ///   - projectPath: Path to the project directory
    ///   - moduleName: Module name (if not provided, will use the directory name)
    public init(projectPath: String, moduleName: String? = nil) {
        self.projectPath = projectPath
        self.moduleName = moduleName
    }
    
    /// Create an architecture model from the configuration
    /// - Returns: The architecture model
    public func createArchitectureModel() throws -> SwiftTarget {
        let builder = ArchitectureModelBuilder()
        return try builder.parseProject(atPath: projectPath, moduleName: moduleName)
    }
}

// MARK: - Convenience Base Test Case

/// Base test case for architecture tests
open class ArchitectureTestCase: XCTestCase, ArchitectureTests {
    /// Configuration for architecture testing
    public let config: ArchitectureTestConfig
    
    /// The architecture model to check against (lazy-loaded)
    public lazy var architecture: SwiftTarget = {
        do {
            return try config.createArchitectureModel()
        } catch {
            fatalError("Failed to create architecture model: \(error)")
        }
    }()
    
    /// Create a new architecture test case
    /// - Parameter config: Configuration for architecture testing
    public init(config: ArchitectureTestConfig) {
        self.config = config
        super.init()
    }
    
    /// Required initializer (not implemented)
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
