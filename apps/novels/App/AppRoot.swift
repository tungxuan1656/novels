import SwiftUI

struct AppRoot: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            LibraryView(router: router)
                .navigationDestination(for: Router.Route.self) { route in
                    // swiftlint:disable switch_case_alignment
                    switch route {
                        case let .reading(bookId):
                            ReadingShellView(bookId: bookId, router: router)
                        case .references:
                            Text("Tài liệu tham khảo")
                                .navigationTitle("Tham khảo")
                    }
                    // swiftlint:enable switch_case_alignment
                }
        }
        .toast(center: router.toast)
        .task {
            router.restoreInitialRoute()
        }
    }
}
