enum ParseError: Error {
  case unexpectedToken((Token, FilePosition))
  case unexpectedEOF
  case invalidComparison(StoredType, StoredType, FilePosition)
  case undefinedType(String, FilePosition)
  case unableToAssignTo(Expr, FilePosition)
}

class Parser {
  let tokens: [(Token, FilePosition)]
  var index = 0
  
  init(tokens: [(Token, FilePosition)]) {
    self.tokens = tokens
  }
  
  var currentToken: (Token, FilePosition)? {
    return index < tokens.count ? tokens[index] : nil
  }
  
  func consumeToken(n: Int = 1) {
    index += n
  }
  
  func parseFile() throws -> File {
    let file = File()
    while let (tok, _) = currentToken {
      switch tok {
      case .struct:
        file.addType(try parseStruct())
      case .extern:
        file.addExtern(try parseExtern())
      case .def:
        file.addDefinition(try parseDefinition())
      case .semicolon:
        consumeToken()
      default:
        let expr = try parseExpr()
        file.addExpression(expr)
      }
    }
    return file
  }
  
  func parseExpr() throws -> Expr {
    guard let (token, position) = currentToken else {
      throw ParseError.unexpectedEOF
    }
    var expr: Expr
    switch token {
    case .leftParen: // ( <expr> )
      consumeToken()
      expr = try parseExpr()
      try consume(.rightParen)
    case .literal(let value):
      consumeToken()
      expr = .literal(value)
    case .var:
      expr = .variableDefinition(try parseVariableDefinition())
    case .identifier(let value):
      consumeToken()
      if case .leftParen? = currentToken?.0 {
        let params = try parseCommaSeparated(parseExpr)
        expr = .call(value, params)
      } else {
        expr = .variable(value)
      }
    case .if: // if <expr> then <expr> else <expr>
      consumeToken()
      let cond = try parseExpr()
      try consume(.leftBrace)
      var thenBlock = [Expr]()
      while( currentToken?.0 != .rightBrace) {
        try thenBlock.append(parseExpr())
      }
      consumeToken() //rightBrace
      var elseBlock = [Expr]()
      if currentToken?.0 == .else {
        consumeToken() // else
        try consume(.leftBrace)
        while( currentToken?.0 != .rightBrace) {
          try elseBlock.append(parseExpr())
        }
      }
      consumeToken() //rightBrace
      expr = .ifelse(cond, thenBlock, elseBlock)
    case .return:
      consumeToken()
      expr = .return(try parseExpr())
    case .for:
      consumeToken()
      print("Found for")
      try consume(.leftParen)
      print("Found bracket")
      let assignment = try parseExpr()
      print("Found assignment")
      try consume(.semicolon)
      let condition = try parseExpr()
      print("Found condition \(condition)")
      try consume(.semicolon)
      print("Found semicolon")
      let postOp = try parseExpr()
      print("Found post op")
      try consume(.rightParen)
      try consume(.leftBrace)
      print("Found body")
      var body = [Expr]()
      while( currentToken?.0 != .rightBrace) {
        print("looking for body")
        try body.append(parseExpr())
        print("Found expr \(body.last!)")
      }
      try consume(.rightBrace)
      body.append(postOp)
      expr = .forLoop(assignment, condition, body)
    default:
      print("Expected Expression")
      throw ParseError.unexpectedToken(token, position)
    }
    
    if case .operator(let op)? = currentToken?.0 {
      consumeToken()
      let rhs = try parseExpr()
      expr = .binary(expr, op, rhs)
    }
    
    if case .logicalOperator(let op)? = currentToken?.0 {
      consumeToken()
      let rhs = try parseExpr()
//      guard expr.resolvedType == rhs.resolvedType else {
//        throw ParseError.invalidComparison(expr.resolvedType, rhs.resolvedType, position)
//      }
      expr = .logical(expr, op, rhs)
    }
    
    if case .assign? = currentToken?.0 {
      consumeToken()
      guard case .variable(let name) = expr else {
        throw ParseError.unableToAssignTo(expr, position)
      }
      
      let rhs = try parseExpr()
      expr = .variableAssignment(name, rhs)
    }
    
    return expr
  }
  
  func consume(_ token: Token) throws {
    guard let (tok, pos) = currentToken else {
      throw ParseError.unexpectedEOF
    }
    guard token == tok else {
      print("Expected token \(token)")
      throw ParseError.unexpectedToken(tok, pos)
    }
    consumeToken()
  }
  
  func parseIdentifier() throws -> String {
    guard let (token, pos) = currentToken else {
      throw ParseError.unexpectedEOF
    }
    guard case .identifier(let name) = token else {
      print("Expected Identifier")
      throw ParseError.unexpectedToken(token, pos)
    }
    consumeToken()
    return name
  }
  
  func parseType() throws -> StoredType {
    let typeString = try parseIdentifier()
    guard let storedType = typeString.toType() else {
      throw ParseError.undefinedType(typeString, currentToken!.1)
    }
    return storedType
  }
  
  func parseVariableDefinition() throws -> VariableDefinition {
    consumeToken()
    let name = try parseIdentifier()
    try consume(.colon)
    let type = try parseType()
    return VariableDefinition(name: name, type: type)
  }
  
  func parseParameter() throws -> VariableDefinition {
    let name = try parseIdentifier()
    try consume(.colon)
    let storedType = try parseType()
    return VariableDefinition(name: name, type: storedType)
  }
  
  func parsePrototype() throws -> Prototype {
    let name = try parseIdentifier()
    let params = try parseCommaSeparated(parseParameter)
    
    let returnType: StoredType
    if currentToken?.0 == .leftBrace {
      returnType = VoidStore()
    } else {
      returnType = try parseType()
    }
    
    return Prototype(name: name, params: params, returnType: returnType)
  }
  
  func parseCommaSeparated<TermType>(_ parseFn: () throws -> TermType) throws -> [TermType] {
    try consume(.leftParen)
    var vals = [TermType]()
    while let (tok, _) = currentToken, tok != .rightParen {
      let val = try parseFn()
      if case .comma? = currentToken?.0 {
        try consume(.comma)
      }
      vals.append(val)
    }
    try consume(.rightParen)
    return vals
  }
  
  func parseExtern() throws -> Prototype {
    try consume(.extern)
    let proto = try parsePrototype()
    try consume(.semicolon)
    return proto
  }
  
  func parseDefinition() throws -> Definition {
    try consume(.def)
    let prototype = try parsePrototype()
    try consume(.leftBrace)
    var expressions = [Expr]()
    while currentToken?.0 != .rightBrace {
      expressions.append(try parseExpr())
    }
    let def = Definition(prototype: prototype, expr: expressions)
    try consume(.rightBrace)
    return def
  }
  
  func parseStruct() throws -> TypeDefinition {
    try consume(.struct)
    guard let (token, _) = currentToken,
          case let .identifier(name) = token else {
      if let (token, pos) = currentToken {
        throw ParseError.unexpectedToken(token, pos)
      }
      throw ParseError.unexpectedEOF
    }
    consumeToken()
    try consume(.leftBrace)
    var properties = [VariableDefinition]()
    while currentToken?.0 != .rightBrace {
      properties.append(try parseVariableDefinition())
    }
    try consume(.rightBrace)
    return TypeDefinition(name: name, properties: properties)
  }
}

extension String {
  var types: [StoredType.Type] {
    return [DoubleStore.self, IntStore.self, FloatStore.self, StringStore.self, CustomStore.self]
  }
  
  func toType() -> StoredType? {
    for type in types {
      if let store = type.init(name: self) {
        return store
      }
    }
    return nil
  }
}
