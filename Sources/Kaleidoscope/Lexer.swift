#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

enum BinaryOperator: UnicodeScalar {
  case plus = "+", minus = "-",
  times = "*", divide = "/",
  mod = "%"
}

enum LogicalOperator: String {
  case and = "&&"
  case or = "||"
  case equals = "=="
  case notEqual = "!="
  case lessThan = "<"
  case lessThanOrEqual = "<="
  case greaterThan = ">"
  case greaterThanOrEqual = ">="
}

enum LiteralType: Equatable {
  case float(Float)
  case double(Double)
  case integer(Int)
  case string(String)
  
  static func ==(lhs: LiteralType, rhs: LiteralType) -> Bool {
    switch (lhs, rhs) {
    case let (.float(float1), .float(float2)):
      return float1 == float2
    case let (.double(double1), .double(double2)):
      return double1 == double2
    case let (.integer(int1), .integer(int2)):
      return int1 == int2
    case let (.string(string1),.string(string2)):
      return string1 == string2
    default:
      return false
    }
  }
}

enum Token: Equatable {
  // Punctuation
  case leftParen, rightParen, comma, semicolon, colon, leftBrace, rightBrace, assign
  // Definitions
  case def, extern, `var`, `struct`
  //Control Flow
  case `if`, then, `else`, `return`, `for`, `while`
  case identifier(String)
  case literal(LiteralType)
  case `operator`(BinaryOperator)
  case logicalOperator(LogicalOperator)
  
  static func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case (.leftParen, .leftParen), (.rightParen, .rightParen),
         (.def, .def), (.extern, .extern), (.comma, .comma),
         (.semicolon, .semicolon), (.if, .if), (.then, .then),
         (.else, .else), (.colon, .colon), (.leftBrace, .leftBrace),
         (.rightBrace, .rightBrace), (.return, .return), (.var, .var),
         (.assign, .assign), (.for, .for), (.while, .while),
         (.struct, .struct):
      return true
    case let (.identifier(id1), .identifier(id2)):
      return id1 == id2
    case let (.literal(l1), .literal(l2)):
      return l1 == l2
    case let (.operator(op1), .operator(op2)):
      return op1 == op2
    case let (.logicalOperator(op1), .logicalOperator(op2)):
      return op1 == op2
    default:
      return false
    }
  }
  
  var expectedString: String? {
    switch self {
    case .logicalOperator(let op1):
      return op1.rawValue
    default:
      return nil
    }
  }
}

struct FilePosition {
  let line: Int
  let position: Int
}

extension Character {
  var value: Int32 {
    return Int32(String(self).unicodeScalars.first!.value)
  }
  var isSpace: Bool {
    return isspace(value) != 0
  }
  var isAlphanumeric: Bool {
    return isalnum(value) != 0 || self == "_"
  }
}

class Lexer {
  var input: String
  var index: String.Index
  var lastTokenIndex: String.Index
  
  var currentPos = FilePosition(line: 1, position: 1)
  
  init(input: String) {
    self.input = input
    self.index = input.startIndex
    self.lastTokenIndex = self.index
  }
  
  var currentChar: Character? {
    return index < input.endIndex ? input[index] : nil
  }
  
  func resetIndex() {
    index = input.startIndex
  }
  
  func advanceIndex() {
    if let currentChar = currentChar,
      currentChar == "\n" {
      currentPos = FilePosition(line: currentPos.line+1, position: 0)
    }
    input.characters.formIndex(after: &index)
    currentPos = FilePosition(line: currentPos.line, position: currentPos.position+1)
  }
  
  func restartCurrentToken() {
    index = lastTokenIndex
  }
  
  func stripComments() {
    while let range = input.range(of: "//") {
      index = range.lowerBound
      print("Found comment at \(index)")
      consumeToNextLine()
    }
  }
  
  func readIdentifierOrNumber() -> String {
    var str = ""
    while let char = currentChar, char.isAlphanumeric || char == "." {
      str.characters.append(char)
      advanceIndex()
    }
    return str
  }
  
  func consumeRest(of token: Token) -> Token? {
    guard var expectedString = token.expectedString else {
      return nil
    }
    expectedString.characters.removeFirst()
    advanceIndex()
    while expectedString.isEmpty == false {
      let nextChar = expectedString.characters.removeFirst()
      if nextChar != currentChar {
        restartCurrentToken()
        return nil
      }
      advanceIndex()
    }
    return token
  }
  
  func consumeToNextLine() {
    let startIndex = index
    while let char = currentChar, char != "\n" {
      advanceIndex()
    }
    input.removeSubrange(startIndex..<index)
  }
  
  func advanceToNextToken() -> Token? {
    // Skip all spaces until a non-space token
    while let char = currentChar, char.isSpace {
      advanceIndex()
    }
    // If we hit the end of the input, then we're done
    guard let char = currentChar else {
      return nil
    }
    
    lastTokenIndex = index
    
    // Handle single-scalar tokens, like comma,
    // leftParen, rightParen, and the operators
    let singleTokMapping: [Character: Token] = [
      ",": .comma, "(": .leftParen, ")": .rightParen,
      ";": .semicolon, "+": .operator(.plus), "-": .operator(.minus),
      "*": .operator(.times), "/": .operator(.divide),
      "%": .operator(.mod), "=": .assign,
      ":": .colon, "{": .leftBrace, "}": .rightBrace,
      "<": .logicalOperator(.lessThan), ">": .logicalOperator(.greaterThan)
    ]
    
    let multiTokMapping: [Character: Token] = [
      "&": .logicalOperator(.and),
      "|": .logicalOperator(.or),
      "=": .logicalOperator(.equals),
      "<": .logicalOperator(.lessThanOrEqual),
      ">": .logicalOperator(.greaterThanOrEqual),
      "!": .logicalOperator(.notEqual)
    ]
    
    if let tok = multiTokMapping[char],
       let token = consumeRest(of: tok) {
      return token
    }
    
    if let tok = singleTokMapping[char] {
      advanceIndex()
      return tok
    }

    // This is where we parse identifiers or numbers
    // We're going to use Swift's built-in double parsing
    // logic here.
    if char.isAlphanumeric {
      let str = readIdentifierOrNumber()
      
      if let i = Int(str) {
        return .literal(.integer(i))
      }
      
      if "f" == str.characters.last,
         let flt = Float(str) {
        return .literal(.float(flt))
      }
      
      if let dbl = Double(str) {
        return .literal(.double(dbl))
      }
      
      
      
      // Look for known tokens, otherwise fall back to
      // the identifier token
      switch str {
        case "def": return .def
        case "extern": return .extern
        case "if": return .if
        case "then": return .then
        case "else": return .else
        case "return": return .return
        case "var": return .var
        case "for": return .for
        case "while": return .while
        case "struct": return .struct
        default: return .identifier(str)
      }
    }
    return nil
  }
  
  func lex() -> [(Token, FilePosition)] {
    stripComments()
    resetIndex()
    var toks = [(Token, FilePosition)]()
    while let tok = advanceToNextToken() {
      toks.append((tok, currentPos))
    }
    return toks
  }
}
