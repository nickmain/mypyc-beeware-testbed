//
//  PyTestApp.swift
//  PyTest
//
//  Created by Nick Main on 2/14/22.
//

import SwiftUI

@main
struct PyTestApp: App {
    @StateObject var python = PythonLogic()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(python)
        }
    }
}
