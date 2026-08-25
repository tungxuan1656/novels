import SwiftUI

struct LibraryView: View {
    @Bindable var router: Router

    var body: some View {
        Text("Thư viện")
            .navigationTitle("Thư viện")
            .navigationBarTitleDisplayMode(.large)
    }
}
