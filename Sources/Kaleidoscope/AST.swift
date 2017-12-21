import LLVM

struct Prototype {
  let name: String
  let params: [VariableDefinition]
  let returnType: StoredType
}

struct TypeDefinition {
  let name: String
  let properties: [VariableDefinition]
}

struct Definition {
  let prototype: Prototype
  let expr: [Expr]
}

struct VariableDefinition {
  let name: String
  let type: StoredType
}

class File {
  private(set) var externs = [Prototype]()
  private(set) var definitions = [Definition]()
  private(set) var expressions = [Expr]()
  private(set) var prototypeMap = [String: Prototype]()
  private(set) var customTypes = [TypeDefinition]()
  
  func prototype(name: String) -> Prototype? {
    return prototypeMap[name]
  }
  
  func addExpression(_ expression: Expr) {
    expressions.append(expression)
  }
  
  func addExtern(_ prototype: Prototype) {
    externs.append(prototype)
    prototypeMap[prototype.name] = prototype
  }
  
  func addDefinition(_ definition: Definition) {
    definitions.append(definition)
    prototypeMap[definition.prototype.name] = definition.prototype
  }
  
  func addType(_ type: TypeDefinition) {
    customTypes.append(type)
  }
}

indirect enum Expr {
  case literal(LiteralType)
  case variable(String)
  case variableDefinition(VariableDefinition)
  case variableDereference(Expr, Expr)
  case variableAssignment(String, Expr)
  case binary(Expr, BinaryOperator, Expr)
  case logical(Expr, LogicalOperator, Expr)
  case ifelse(Expr, [Expr], [Expr])
  case forLoop(Expr, Expr, [Expr])
  case whileLoop(Expr,[Expr])
  case call(String, [Expr])
  case `return`(Expr)
  
  var resolvedType: StoredType {
    switch self {
    case .literal(.integer):
      return IntStore()
    case .literal(.float):
      return FloatStore()
    case .literal(.double):
      return DoubleStore()
    case .literal(.string):
      return StringStore()
    case .variable:
      return VoidStore()
    case .variableDereference(let parentExpr, let childExpr):
      return childExpr.resolvedType
    case .call:
      return VoidStore()
    case .binary(let lhs, _, _):
      //Assuming that lhs and rhs will have the same type
      return lhs.resolvedType
    case .logical:
      return IntStore()
    default:
      return VoidStore()
    }
  }
}
