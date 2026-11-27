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

    #if os(iOS)
    @MainActor
    init() {
        // Registration must occur during app launch, before requests are submitted.
        if !Self.isUnitTestHost {
            ContinuedPrefetchCoordinator.shared.register()
        }
    }

    #endif

    var body: some Scene {
        #if os(macOS)
        Window("Truyện", id: "main") {
            if !Self.isUnitTestHost {
                AppRoot()
                    .frame(minWidth: 420, minHeight: 480)
            }
        }
        .defaultSize(width: 900, height: 760)
        #else
        WindowGroup {
            // Hosted unit tests must not restore sessions or create production stores/services.
            if !Self.isUnitTestHost {
                AppRoot()
            }
        }
        #endif
    }
}
