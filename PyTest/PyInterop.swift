//
//  PyInterop.swift
//  PyTest
//
//  Created by Nick Main on 2/14/22.
//

import Foundation
import Combine


@MainActor
class PythonLogic: ObservableObject {
    
    private let python: Python
    private let helloModule: Python.Module?
    
    init() {
        let python = Python()
        self.python = python
        
        helloModule = try? Python.GIL_throws{
            try? python.importModule(named: "hello")
        }
    }
    
    func exec(_ src: String) {
        Python.GIL {
            PyRun_SimpleString(src)
        }
    }
    
    // evaluate an expression
    func eval(_ src: String) -> Python.Object {
        Python.GIL {
            guard let module = helloModule else { return Python.None() }
            
            let globals = module.getDict()
            let locals = globals
            
            do {
                return try python.eval(expression: src, globals: globals, locals: locals)

            } catch Python.Error.value(let value) {
                let msg = "❌ \((try? value.getRepr().toString()) ?? "???")"
                print(msg)
                return Python.Str(msg)
            } catch {
                let msg = "❌ \(error)"
                print(msg)
                return Python.Str(msg)
            }
        }
    }
}
