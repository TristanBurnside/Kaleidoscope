import LLVM

struct GeneratorType {
  let definition: TypeDefinition
  let llvm: StructType
}

enum IRError: Error, CustomStringConvertible {
  case unknownFunction(String)
  case unknownVariable(String)
  case wrongNumberOfArgs(String, expected: Int, got: Int)
  case nonTruthyType(IRType)
  case unprintableType(IRType)
  case unableToCompare(IRType, IRType)
  case expectedParameterDefinition(String)
  case unknownMember(String)
  case unknownType(String)
  
  var description: String {
    switch self {
    case .unknownFunction(let name):
      return "unknown function '\(name)'"
    case .unknownVariable(let name):
      return "unknown variable '\(name)'"
    case .wrongNumberOfArgs(let name, let expected, let got):
      return "call to function '\(name)' with \(got) arguments (expected \(expected))"
    case .nonTruthyType(let type):
      return "logical operation found non-truthy type: \(type)"
    case .unprintableType(let type):
      return "unable to print result of type \(type)"
    case .unableToCompare(let type1, let type2):
      return "unable to compare \(type1) with \(type2)"
    case .expectedParameterDefinition(let name):
      return "expected parameter definition in declaration of function \(name)"
    case .unknownMember(let name):
      return "No member: \(name) in type"
    case .unknownType(let name):
      return "No type defined called \(name)"
    }
  }
}

extension IRType: Hashable {
    var hashValue: Int {
        return 0
    }
}

class IRGenerator {
  let module: Module
  let builder: IRBuilder
  let file: File
  
  private var parameterValues: StackMemory
  private var typesByIR: [IRType: GeneratorType]
    private var typesByName: [String: GeneratorType]
  
  
  init(moduleName: String = "main", file: File) {
    self.module = Module(name: moduleName)
    self.builder = IRBuilder(module: module)
    self.file = file
    parameterValues = StackMemory(builder: builder)
    typesByName = [:]
    typesByIR = [:]
  }
  
  func emit() throws {
    for extern in file.externs {
      try emitPrototype(extern)
    }
    for type in file.customTypes {
      try defineType(type)
    }
    for type in file.customTypes {
      try populateType(type)
    }
    for definition in file.definitions {
      try emitDefinition(definition)
    }
    try emitMain()
  }
  
  func emitPrintf() -> Function {
    if let function = module.function(named: "printf") { return function }
    let printfType = FunctionType(argTypes: [PointerType(pointee: IntType.int8)],
                                  returnType: IntType.int32,
                                  isVarArg: true)
    return builder.addFunction("printf", type: printfType)
  }
  
  func defineType(_ type: TypeDefinition) throws {
    let newType = builder.createStruct(name: type.name, types: nil)
    let generatorType = GeneratorType(definition: type, llvm: newType)
    typesByIR[newType] = generatorType
    typesByName[type.name] = generatorType
  }
  
  func populateType(_ type: TypeDefinition) throws {
    guard let genType = typesByName[type.name] else {
      throw IRError.unknownType(type.name)
    }
    try genType.llvm.setBody(type.properties.map{ $0.type }.map{ try $0.findType(types: types) })
  }
  
  func emitMain() throws {
    let mainType = FunctionType(argTypes: [], returnType: VoidType())
    let function = builder.addFunction("main", type: mainType)
    let entry = function.appendBasicBlock(named: "entry")
    builder.positionAtEnd(of: entry)
    
    let printf = emitPrintf()
    
    for expr in file.expressions {
      let val = try emitExpr(expr)
      guard let valType = val.type as? Printable else {
        throw IRError.unprintableType(val.type)
      }
      let _ = builder.buildCall(printf, args: [valType.printFormat(module: module, builder: builder), val])
    }
    
    builder.buildRetVoid()
  }
  
  @discardableResult // declare double @foo(double %n, double %m)
  func emitPrototype(_ prototype: Prototype) throws -> Function {
    if let function = module.function(named: prototype.name) {
      return function
    }
    let argTypes = try prototype.params.map{ $0.type }.map{ try $0.findType(types: typesByName) }
    
    let funcType = try FunctionType(argTypes: argTypes,
                                returnType: prototype.returnType.findType(types: types))
    let function = builder.addFunction(prototype.name, type: funcType)
    
    for (var param, name) in zip(function.parameters, prototype.params.map{ $0.name }) {
      param.name = name
    }
    
    return function
  }
  
  @discardableResult
  func emitDefinition(_ definition: Definition) throws -> Function {
    let function = try emitPrototype(definition.prototype)
    
    parameterValues.startFrame()
    
    for (idx, arg) in definition.prototype.params.enumerated() {
      let param = function.parameter(at: idx)!
      parameterValues.addStatic(name: arg.name, value: param)
    }
    
    let entryBlock = function.appendBasicBlock(named: "entry")
    builder.positionAtEnd(of: entryBlock)
    
    try definition.expr.forEach { let _ = try emitExpr($0) }
    
    parameterValues.endFrame()
    
    return function
  }
  
  func emitExpr(_ expr: Expr) throws -> IRValue {
    switch expr {
    case .variableDefinition(let definition):
      parameterValues.addVariable(name: definition.name, type: try definition.type.findType(types: typesByName))
      return VoidType().undef()
    case .variable(let name):
      guard let param = parameterValues.getVariable(name: name) else {
        throw IRError.unknownVariable(name)
      }
      return param
    case .variableDereference(let instance, .variable(let member)):
        let instanceIR = try emitExpr(instance)
        guard let type = typesByIR[instanceIR.type] else {
            throw IRError.unknownMember(member)
        }
        guard let (elementIndex, _) = type.definition.properties.enumerated.filter{ $1.name == member }.first else {
            throw IRError.unknownMember(member)
        }
        return builder.buildStructGEP(instanceIR, elementIndex, member)
    case .variableAssignment(let name, let expr):
      let value = try emitExpr(expr)
      try parameterValues.setVariable(name: name, value: value)
      return VoidType().undef()

    case .literal(.double(let value)):
      return FloatType.double.constant(value)
    case .literal(.float(let value)):
      return FloatType.float.constant(Double(value))
    case .literal(.integer(let value)):
      return value.asLLVM()
    case .literal(.string(let value)):
      return value.asLLVM()
    case .binary(let lhs, let op, let rhs):
      let lhsVal = try emitExpr(lhs)
      let rhsVal = try emitExpr(rhs)
      switch op {
      case .plus:
        return builder.buildAdd(lhsVal, rhsVal)
      case .minus:
        return builder.buildSub(lhsVal, rhsVal)
      case .divide:
        return builder.buildDiv(lhsVal, rhsVal)
      case .times:
        return builder.buildMul(lhsVal, rhsVal)
      case .mod:
        return builder.buildRem(lhsVal, rhsVal)
      }
    case .logical(let lhs, let op, let rhs):
      let lhsVal = try emitExpr(lhs)
      let rhsVal = try emitExpr(rhs)
      
      let lhsCond = try lhsVal.truthify(builder: builder)
      let rhsCond = try rhsVal.truthify(builder: builder)
      
      var comparisonType: (float: RealPredicate, int: IntPredicate)? = nil
      
      switch op {
      case .and:
        let intRes = builder.buildAnd(lhsCond, rhsCond)
        return intRes
      case .or:
        let intRes = builder.buildOr(lhsCond, rhsCond)
        return intRes
      case .equals:
        comparisonType = (.orderedEqual, .equal)
      case .notEqual:
        comparisonType = (.orderedNotEqual, .notEqual)
      case .lessThan:
        comparisonType = (.orderedLessThan, .signedLessThan)
      case .lessThanOrEqual:
        comparisonType = (.orderedLessThanOrEqual, .signedLessThanOrEqual)
      case .greaterThan:
        comparisonType = (.orderedGreaterThan, .signedGreaterThan)
      case .greaterThanOrEqual:
        comparisonType = (.orderedGreaterThanOrEqual, .signedGreaterThanOrEqual)
      }
      if lhsVal.type is FloatType,
        rhsVal.type is FloatType {
        return builder.buildFCmp(lhsVal, rhsVal, comparisonType!.float)
      }
      if lhsVal.type is IntType,
        rhsVal.type is IntType {
        return builder.buildICmp(lhsVal, rhsVal, comparisonType!.int)
      }
      throw IRError.unableToCompare(lhsVal.type, rhsVal.type)
      
    case .call(let name, let args):
      guard let prototype = file.prototype(name: name) else {
        throw IRError.unknownFunction(name)
      }
      guard prototype.params.count == args.count else {
        throw IRError.wrongNumberOfArgs(name,
                                        expected: prototype.params.count,
                                        got: args.count)
      }
      let callArgs = try args.map(emitExpr)
      let function = try emitPrototype(prototype)
      return builder.buildCall(function, args: callArgs)
    case .return(let expr):
      let innerVal = try emitExpr(expr)
      return builder.buildRet(innerVal)
    case .ifelse(let cond, let thenBlock, let elseBlock):
      let condition = try emitExpr(cond)
      let truthCondition = try condition.truthify(builder: builder)
      let checkCond = builder.buildICmp(truthCondition,
                                        (truthCondition.type as! IntType).zero(),
                                        .notEqual)
      
      let thenBB = builder.currentFunction!.appendBasicBlock(named: "then")
      let elseBB = builder.currentFunction!.appendBasicBlock(named: "else")
      let mergeBB = builder.currentFunction!.appendBasicBlock(named: "merge")
      
      builder.buildCondBr(condition: checkCond, then: thenBB, else: elseBB)
      
      builder.positionAtEnd(of: thenBB)
      try thenBlock.forEach { let _ = try emitExpr($0) }
      builder.buildBr(mergeBB)
      
      builder.positionAtEnd(of: elseBB)
      try elseBlock.forEach { let _ = try emitExpr($0) }
      builder.buildBr(mergeBB)
      
      builder.positionAtEnd(of: mergeBB)
      
      return VoidType().undef()
    case .forLoop(let ass, let cond, let body):
      parameterValues.startFrame()
      defer {
        parameterValues.endFrame()
      }
      let startBB = builder.currentFunction!.appendBasicBlock(named: "setup")
      let bodyBB = builder.currentFunction!.appendBasicBlock(named: "body")
      let cleanupBB = builder.currentFunction!.appendBasicBlock(named: "cleanup")
      
      builder.buildBr(startBB)
      
      builder.positionAtEnd(of: startBB)
      let _ = try emitExpr(ass)
      let startCondition = try emitExpr(cond)
      let startTruthCondition = try startCondition.truthify(builder: builder)
      let startCheckCond = builder.buildICmp(startTruthCondition,
                                        (startTruthCondition.type as! IntType).zero(),
                                        .notEqual)
      builder.buildCondBr(condition: startCheckCond, then: bodyBB, else: cleanupBB)

      
      builder.positionAtEnd(of: bodyBB)
      try body.forEach { let _ = try emitExpr($0) }
      let endCondition = try emitExpr(cond)
      let endTruthCondition = try endCondition.truthify(builder: builder)
      let endCheckCond = builder.buildICmp(endTruthCondition,
                                        (endTruthCondition.type as! IntType).zero(),
                                        .notEqual)
      builder.buildCondBr(condition: endCheckCond, then: bodyBB, else: cleanupBB)
      builder.positionAtEnd(of: cleanupBB)
      
      return VoidType().undef()
    case .whileLoop(let cond, let body):
      parameterValues.startFrame()
      defer {
        parameterValues.endFrame()
      }
      let startBB = builder.currentFunction!.appendBasicBlock(named: "setup")
      let bodyBB = builder.currentFunction!.appendBasicBlock(named: "body")
      let cleanupBB = builder.currentFunction!.appendBasicBlock(named: "cleanup")
      
      builder.positionAtEnd(of: startBB)
      let startCondition = try emitExpr(cond)
      let startTruthCondition = try startCondition.truthify(builder: builder)
      let startCheckCond = builder.buildICmp(startTruthCondition,
                                             (startTruthCondition.type as! IntType).zero(),
                                             .notEqual)
      builder.buildCondBr(condition: startCheckCond, then: bodyBB, else: cleanupBB)
      
      builder.positionAtEnd(of: bodyBB)
      try body.forEach { let _ = try emitExpr($0) }
      let endCondition = try emitExpr(cond)
      let endTruthCondition = try endCondition.truthify(builder: builder)
      let endCheckCond = builder.buildICmp(endTruthCondition,
                                           (endTruthCondition.type as! IntType).zero(),
                                           .notEqual)
      builder.buildCondBr(condition: endCheckCond, then: bodyBB, else: cleanupBB)
      builder.positionAtEnd(of: cleanupBB)
      
      return VoidType().undef()
    }
  }
}

extension StoredType {
  func findType(types: [String: GeneratorType]) throws -> IRType {
    if let type = IRType {
      return type
    }
    guard let generatorType = types[name] else {
      throw IRError.unknownType(name)
    }
    return PointerType(pointee: generatorType.llvm)
  }
}

extension IRValue {
  func truthify(builder: IRBuilder) throws -> IRValue {
    if let truthVal = self.type.truthify(value:self, with: builder) {
      return truthVal
    }
    throw IRError.nonTruthyType(self.type)
  }
}

extension IRType {
  func truthify(value: IRValue, with builder: IRBuilder) -> IRValue? {
    if let truthable = self as? Truthable {
      return truthable.truthy(value: value, with: builder)
    }
    return nil
  }
}

protocol Truthable {
  func truthy(value: IRValue, with builder: IRBuilder) -> IRValue
}

extension FloatType: Truthable {
  func truthy(value: IRValue, with builder: IRBuilder) -> IRValue {
    return builder.buildFPToInt(value, type: .int1, signed: false)
  }
}

extension IntType: Truthable {
  func truthy(value: IRValue, with builder: IRBuilder) -> IRValue {
    return value
  }
}

protocol Printable {
  func printFormat(module: Module, builder: IRBuilder) -> IRValue
}

extension IntType: Printable {
  func printFormat(module: Module, builder: IRBuilder) -> IRValue {
    guard let format = module.global(named: "IntPrintFormat") else {
      return builder.buildGlobalStringPtr("%d\n", name: "IntPrintFormat")
    }
    return format.constGEP(indices: [0, 0])
  }
}

extension FloatType: Printable {
  func printFormat(module: Module, builder: IRBuilder) -> IRValue {
    guard let format = module.global(named: "FloatPrintFormat") else {
      return builder.buildGlobalStringPtr("%f\n", name: "FloatPrintFormat")
    }
    return format.constGEP(indices: [0, 0])
  }
}
