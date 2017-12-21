//
//  StackMemory.swift
//  Kaleidescope
//
//  Created by Tristan Burnside on 13/8/17.
//  Copyright © 2017 Tristan Burnside. All rights reserved.
//

import LLVM

final class StackMemory {
  private let builder: IRBuilder
  private var frames: [StackFrame]
  
  init(builder: IRBuilder) {
    self.builder = builder
    frames = []
  }
  
  func addStatic(name: String, value: IRValue) {
    frames.last?.statics[name] = value
  }
  
  func addVariable(name: String, type: IRType) {
    let newVar = builder.buildAlloca(type: type, name: name)
    frames.last?.variables[name] = newVar
  }
  
  func getVariable(name: String) -> IRValue? {
    for frame in frames.reversed() {
      if let variableRef = frame.variables[name] {
        return builder.buildLoad(variableRef)
      }
      if let staticRef = frame.statics[name] {
        return staticRef
      }
    }
    return nil
  }
  
  func setVariable(name: String, value: IRValue) throws {
    for frame in frames.reversed() {
      if let variableRef = frame.variables[name] {
        builder.buildStore(value, to: variableRef)
        return
      }
    }
    throw IRError.unknownVariable(name)
  }
  
  func startFrame() {
    frames.append(StackFrame())
  }
  
  func endFrame() {
    frames.removeLast()
  }
}

final class StackFrame {
  var statics: [String: IRValue]
  var variables: [String: IRValue]
  
  init() {
    statics = [:]
    variables = [:]
  }
}
