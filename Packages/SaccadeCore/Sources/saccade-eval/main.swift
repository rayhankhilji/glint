import Foundation
import SaccadeEval

let code = SaccadeEval.run(arguments: Array(CommandLine.arguments.dropFirst())) { print($0) }
exit(code)
