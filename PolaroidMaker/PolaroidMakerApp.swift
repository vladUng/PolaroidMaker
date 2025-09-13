//
//  PolaroidMakerApp.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import SwiftUI

@main
struct PolaroidMakerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowResizability(.contentSize)
    }
}
