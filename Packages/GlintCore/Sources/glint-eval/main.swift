import Foundation
import GlintEval

let code = GlintEval.run(arguments: Array(CommandLine.arguments.dropFirst())) { print($0) }
exit(code)
