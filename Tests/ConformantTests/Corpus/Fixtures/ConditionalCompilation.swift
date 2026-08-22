#if canImport(UIKit)
import UIKit
public class PlatformView: UIView {}
#elseif canImport(AppKit)
import AppKit
public class PlatformView: NSView {}
#else
public class PlatformView {}
#endif

#if DEBUG
func debugOnly() -> DebugTool { DebugTool() }
#endif
