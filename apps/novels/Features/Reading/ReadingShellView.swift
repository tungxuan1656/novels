import SwiftUI

struct ReadingShellView: View {
    let bookId: String
    @Bindable var router: Router

    var body: some View {
        ReaderView(bookId: bookId, router: router)
    }
}
