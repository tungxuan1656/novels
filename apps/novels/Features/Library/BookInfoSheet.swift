import SwiftUI

struct BookInfoSheet: View {
    let book: Book

    var body: some View {
        Text(book.name)
            .navigationTitle("Thông tin sách")
    }
}
