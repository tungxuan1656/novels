//
//  NovelsApp.swift
//  novels
//
//  Created by Tùng Đoàn on 24/8/26.
//

import SwiftUI

@main
struct NovelsApp: App {
    static let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    @MainActor
    init() {
        // Registration must occur during app launch, before requests are submitted.
        if !Self.isUnitTestHost {
            ContinuedPrefetchCoordinator.shared.register()
        }
    }

    var body: some Scene {
        WindowGroup {
            // Hosted unit tests must not restore sessions or create production stores/services.
            if !Self.isUnitTestHost {
                AppRoot()
            }
        }
    }
}
