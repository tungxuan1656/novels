//
//  NovelsApp.swift
//  novels
//
//  Created by Tùng Đoàn on 24/8/26.
//

import SwiftUI

@main
struct NovelsApp: App {
    @State private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}
