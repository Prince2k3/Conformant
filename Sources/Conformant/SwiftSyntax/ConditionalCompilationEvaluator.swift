//
//  ConditionalCompilationEvaluator.swift
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
import SwiftSyntax

/// Decides which clauses of an `#if` a given build would compile.
///
/// The answer is three-valued. A predicate the configuration does not describe, such as
/// an unlisted `os`, a `canImport` with no module list, or a form this evaluator does
/// not understand, is *undecided*, and an undecided clause stays in the scope along with
/// every clause that follows it. Dropping a branch that might compile would hide
/// declarations from every rule, and a rule with nothing to check passes.
struct ConditionalCompilationEvaluator {

    enum Answer {
        case yes
        case no
        case undecided
    }

    let configuration: BuildConfiguration

    /// The clauses of `node` whose declarations belong in the scope.
    ///
    /// Clauses are read in source order, exactly as the compiler reads them: the first one
    /// that definitely holds wins, and nothing after it can. Clauses that definitely fail
    /// are dropped. An undecided clause is kept *and* the search continues, because there
    /// is no way to tell whether it would have claimed the ones below it.
    func activeClauses(of node: IfConfigDeclSyntax) -> [IfConfigClauseSyntax] {
        var active: [IfConfigClauseSyntax] = []

        for clause in node.clauses {
            guard let condition = clause.condition else {
                // `#else`. Reaching it at all means no earlier clause definitely held.
                active.append(clause)
                break
            }

            switch evaluate(condition) {
            case .yes:
                active.append(clause)
                return active
            case .no:
                continue
            case .undecided:
                active.append(clause)
            }
        }

        return active
    }

    // MARK: - Conditions

    func evaluate(_ condition: ExprSyntax) -> Answer {
        if let literal = condition.as(BooleanLiteralExprSyntax.self) {
            return literal.literal.tokenKind == .keyword(.true) ? .yes : .no
        }
        if let reference = condition.as(DeclReferenceExprSyntax.self) {
            // A `-D` flag. The configuration names the whole set, so an absent flag is
            // unset rather than unknown.
            return configuration.customFlags.contains(reference.baseName.text) ? .yes : .no
        }
        if let group = condition.as(TupleExprSyntax.self), group.elements.count == 1 {
            return evaluate(group.elements.first!.expression)
        }
        if let prefix = condition.as(PrefixOperatorExprSyntax.self) {
            guard prefix.operator.text == "!" else { return .undecided }
            return negate(evaluate(prefix.expression))
        }
        if let sequence = condition.as(SequenceExprSyntax.self) {
            return evaluate(sequence)
        }
        if let call = condition.as(FunctionCallExprSyntax.self) {
            return evaluate(call)
        }
        return .undecided
    }

    /// `&&` and `||` arrive unfolded, as a flat list of operands and operators, because
    /// `#if` conditions are parsed without applying operator precedence. Group them the
    /// way Swift would: `&&` binds tighter than `||`.
    private func evaluate(_ sequence: SequenceExprSyntax) -> Answer {
        var operands: [ExprSyntax] = []
        var operators: [String] = []

        for (offset, element) in sequence.elements.enumerated() {
            if offset.isMultiple(of: 2) {
                operands.append(element)
            } else if let binary = element.as(BinaryOperatorExprSyntax.self) {
                operators.append(binary.operator.text)
            } else {
                return .undecided
            }
        }

        guard operands.count == operators.count + 1,
              operators.allSatisfy({ $0 == "&&" || $0 == "||" })
        else {
            return .undecided
        }

        var conjunctions: [[ExprSyntax]] = [[operands[0]]]
        for (offset, binary) in operators.enumerated() {
            if binary == "&&" {
                conjunctions[conjunctions.count - 1].append(operands[offset + 1])
            } else {
                conjunctions.append([operands[offset + 1]])
            }
        }

        return anyHolds(conjunctions.map { allHold($0.map(evaluate)) })
    }

    private func evaluate(_ call: FunctionCallExprSyntax) -> Answer {
        guard let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
              let argument = call.arguments.first,
              call.arguments.count == 1
        else {
            // `canImport(Foo, _version: 1.2)` and anything else with an unexpected shape.
            return .undecided
        }

        let name = callee.baseName.text
        let written = argument.expression.trimmedDescription

        switch name {
        case "os":
            return matches(configuration.operatingSystem, written)
        case "arch":
            return matches(configuration.architecture, written)
        case "targetEnvironment":
            return matches(configuration.targetEnvironment, written)
        case "canImport":
            // `canImport(UIKit.UIView)` asks about the module at the root.
            guard let modules = configuration.importableModules else { return .undecided }
            let module = written.split(separator: ".").first.map(String.init) ?? written
            return modules.contains(module) ? .yes : .no
        case "swift":
            return compare(written, against: configuration.swiftVersion)
        case "compiler":
            return compare(written, against: configuration.compilerVersion)
        default:
            // `hasFeature`, `hasAttribute`, `_runtime`, `_endian`, and whatever Swift adds
            // next. Undecided keeps the branch rather than guessing at it.
            return .undecided
        }
    }

    private func matches(_ configured: String?, _ written: String) -> Answer {
        guard let configured else { return .undecided }
        return configured == written ? .yes : .no
    }

    /// `swift(>=5.9)` and `compiler(<6)`. The comparison is the whole argument, operator
    /// included, so both halves are read here.
    private func compare(_ written: String, against configured: String?) -> Answer {
        guard let configured, let build = version(configured) else { return .undecided }

        let comparison: (Bool) -> Answer = { $0 ? .yes : .no }

        if written.hasPrefix(">=") {
            guard let bound = version(String(written.dropFirst(2))) else { return .undecided }
            return comparison(!isLower(build, than: bound))
        }
        if written.hasPrefix("<") {
            guard let bound = version(String(written.dropFirst(1))) else { return .undecided }
            return comparison(isLower(build, than: bound))
        }
        return .undecided
    }

    /// `"5.9.1"` as `[5, 9, 1]`, or `nil` when it is not a plain dotted version.
    private func version(_ written: String) -> [Int]? {
        let components = written.trimmingCharacters(in: .whitespaces).split(separator: ".")
        guard !components.isEmpty else { return nil }

        var numbers: [Int] = []
        for component in components {
            guard let number = Int(component) else { return nil }
            numbers.append(number)
        }
        return numbers
    }

    /// Component-wise, treating a missing component as zero so `5.9` and `5.9.0` agree.
    private func isLower(_ lhs: [Int], than rhs: [Int]) -> Bool {
        for offset in 0..<max(lhs.count, rhs.count) {
            let left = offset < lhs.count ? lhs[offset] : 0
            let right = offset < rhs.count ? rhs[offset] : 0
            if left != right { return left < right }
        }
        return false
    }

    // MARK: - Three-valued logic

    private func negate(_ answer: Answer) -> Answer {
        switch answer {
        case .yes: return .no
        case .no: return .yes
        case .undecided: return .undecided
        }
    }

    /// One definite failure settles a conjunction; otherwise an undecided term leaves it
    /// undecided.
    private func allHold(_ answers: [Answer]) -> Answer {
        if answers.contains(where: { if case .no = $0 { return true } else { return false } }) {
            return .no
        }
        if answers.contains(where: { if case .undecided = $0 { return true } else { return false } }) {
            return .undecided
        }
        return .yes
    }

    /// One definite success settles a disjunction.
    private func anyHolds(_ answers: [Answer]) -> Answer {
        if answers.contains(where: { if case .yes = $0 { return true } else { return false } }) {
            return .yes
        }
        if answers.contains(where: { if case .undecided = $0 { return true } else { return false } }) {
            return .undecided
        }
        return .no
    }
}
