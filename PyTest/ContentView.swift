//
//  ContentView.swift
//  PyTest
//
//  Created by Nick Main on 2/14/22.
//

import SwiftUI


struct ContentView: View {
    @EnvironmentObject var python: PythonLogic
    @State var value: Python.Object = Python.GIL{ Python.None() }
    
    var body: some View {
        Python.GIL {
            VStack {
                if let string = value.asString() {
                    Text(string.toString())
                }
                else if let tuple = value.asTuple() {
                    VStack {
                        ForEach(0..<tuple.size) { index in
                            let text = try? tuple.getItem(at: index).getRepr().toString()
                            Text(text ?? "---")
                        }
                    }
                }
                else if Python.None.isNone(value) {
                    Text("None")
                }
                else {
                    let text = "Unhandled Python type \(value.getType())"
                    Text(text)
                }
                
                Button("Press Me") {
                    value = python.eval("test()")
                }
                .buttonStyle(.borderedProminent)
            }
            .onAppear {
                value = python.eval("hello()")
            }
            .font(.system(size: 18, weight: .regular, design: .monospaced))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
