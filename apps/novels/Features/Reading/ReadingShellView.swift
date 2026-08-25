import SwiftUI

struct ReadingShellView: View {
    let bookId: String
    @Bindable var router: Router

    var body: some View {
        Text("Đọc sách: \(bookId)")
            .navigationTitle("Đọc sách")
    }
}
