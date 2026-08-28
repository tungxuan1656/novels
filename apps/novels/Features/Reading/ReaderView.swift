import SwiftUI

// swiftlint:disable:next type_body_length
struct ReaderView: View {
    let bookId: String
    @Bindable var router: Router
    @State private var viewModel: ReaderViewModel
    @State private var settingsStore: SettingsStore
    @State private var offsetY: Double = 0
    @State private var overscrollLock = false
    @State private var showSheet = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var debounceTask: Task<Void, Never>?
    @State private var scrollPosition = ScrollPosition(point: .zero)
    @State private var isProgrammaticScrolling = false

    init(
        bookId: String,
        router: Router,
        repository: BookRepository? = nil,
        settingsStore: SettingsStore? = nil
    ) {
        self.bookId = bookId
        self.router = router
        let store = settingsStore ?? SettingsStore.shared
        let repo: BookRepository = repository ?? FileBookRepository(
            root: AppPaths.booksRoot(),
            fileManager: .default
        )
        _viewModel = State(initialValue: ReaderViewModel(
            bookId: bookId,
            repository: repo,
            settingsStore: store,
            toastCenter: router.toast
        ))
        _settingsStore = State(initialValue: store)
    }

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.spacing16) {
                            Color.clear.frame(height: 54)

                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else if viewModel.aiMode != .none {
                                aiSection
                            } else if viewModel.blocks.isEmpty {
                                Text(viewModel.errorMessage ?? "Không tìm thấy chương")
                                    .foregroundStyle(DesignTokens.muted)
                            } else {
                                content
                            }
                            prefetchIndicator
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(DesignTokens.spacing16)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: ContentHeightKey.self,
                                    value: geometry.size.height
                                )
                            }
                        )
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: geometry.frame(in: .named("reader")).minY
                                )
                            }
                        )
                        .id("top")
                    }
                    .coordinateSpace(name: "reader")
                    .scrollPosition($scrollPosition)
                    .onPreferenceChange(ScrollOffsetKey.self) { value in
                        handleOffset(value)
                    }
                    .onPreferenceChange(ContentHeightKey.self) { value in
                        contentHeight = value
                    }
                    .onPreferenceChange(ViewportHeightKey.self) { value in
                        viewportHeight = value
                    }
                    .background(
                        Color.clear.preference(key: ViewportHeightKey.self, value: outer.size.height)
                    )

                    topHeader

                    VStack {
                        Spacer()
                        bottomFloatingBar(proxy)
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    viewportHeight = outer.size.height
                    viewModel.onAppear()
                    Task {
                        await viewModel.load()
                        restoreOffset()
                    }
                }
                .onDisappear {
                    // Flush pending offset before cancelling debounce
                    if debounceTask != nil {
                        viewModel.saveOffset(Double(-offsetY))
                    }
                    debounceTask?.cancel()
                    debounceTask = nil
                    viewModel.onDisappear()
                }
                .onChange(of: outer.size.height) { _, newValue in
                    viewportHeight = newValue
                }
            }
        }
        .background(DesignTokens.backgroundPaper)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showSheet) {
            ReaderBottomSheet(settingsStore: settingsStore, viewModel: viewModel, onClose: { showSheet = false })
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
            if viewModel.isAIProcessing {
                ProgressView("Đang xử lý...")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("aiProgress")
            }
            if let error = viewModel.aiError {
                Text(error)
                    .foregroundStyle(DesignTokens.error)
                    .font(.caption)
                    .accessibilityIdentifier("aiError")
            }
            if let processed = viewModel.processedContent, !processed.isEmpty, !viewModel.isAIProcessing {
                aiProcessedContent(processed)
            } else if !viewModel.isAIProcessing, viewModel.aiError == nil {
                if viewModel.blocks.isEmpty {
                    Text(viewModel.errorMessage ?? "Không tìm thấy chương")
                        .foregroundStyle(DesignTokens.muted)
                } else {
                    content
                }
            } else if viewModel.blocks.isEmpty {
                Text(viewModel.errorMessage ?? "Không tìm thấy chương")
                    .foregroundStyle(DesignTokens.muted)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
            ForEach(Array(viewModel.blocks.enumerated()), id: \.offset) { _, block in
                let combined = block.spans.reduce(Text("")) { accumulator, span in
                    if span.isLineBreak {
                        return accumulator + Text("\n")
                    }
                    var piece = Text(span.text)
                        .font(fontFor(block: block, span: span))
                        .foregroundStyle(DesignTokens.text)
                    if span.kind == .bold || span.kind == .boldItalic {
                        piece = piece.bold()
                    }
                    if span.kind == .italic || span.kind == .boldItalic {
                        piece = piece.italic()
                    }
                    return accumulator + piece
                }
                combined
                    .lineSpacing(CGFloat(settingsStore.typography.lineHeight))
                    .kerning(CGFloat(settingsStore.typography.letterSpacing))
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func aiProcessedContent(_ text: String) -> some View {
        Text(text)
            .font(.system(
                size: CGFloat(settingsStore.typography.fontSize),
                design: ReaderFontDesign.design(for: settingsStore.typography.font)
            ))
            .foregroundStyle(DesignTokens.text)
            .lineSpacing(CGFloat(settingsStore.typography.lineHeight))
            .kerning(CGFloat(settingsStore.typography.letterSpacing))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("aiContent")
    }

    private func fontFor(block: TextBlock, span: TextSpan) -> Font {
        let base = CGFloat(settingsStore.typography.fontSize)
        let design = ReaderFontDesign.design(for: settingsStore.typography.font)
        if block.isHeading {
            let level = CGFloat(block.headingLevel ?? 3)
            return .system(size: base + CGFloat(7 - level) * 2, weight: .bold, design: design)
        }
        return .system(size: base, design: design)
    }

    private var topChapterTitleText: String {
        let num = viewModel.chapterNumber
        let headingBlock = viewModel.blocks.first(where: { $0.isHeading })
        if let headingText = headingBlock?.spans.first?.text, !headingText.isEmpty {
            return "【\(num)】 \(headingText)"
        }
        if let bookName = viewModel.book?.name, !bookName.isEmpty {
            return "【\(num)】 Chương \(num): \(bookName)"
        }
        return "【\(num)】 Chương \(num)"
    }

    private var topHeader: some View {
        VStack(spacing: 6) {
            Text(topChapterTitleText)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(DesignTokens.text)
                .lineLimit(1)
                .accessibilityIdentifier("chapterText")

            HStack {
                Button {
                    router.popReading()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.text)
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .systemGray5).opacity(0.85))
                        .clipShape(Circle())
                }
                .a11yHitTarget()
                .accessibilityIdentifier("backButton")
                .accessibilityLabel("Quay lại Thư viện")

                Spacer()

                HStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Button {
                            debounceTask?.cancel()
                            debounceTask = nil
                            beginProgrammaticScrolling()
                            Task {
                                await viewModel.goPrev()
                                scrollToTop()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    viewModel.canGoPrev
                                        ? DesignTokens.text
                                        : DesignTokens.muted.opacity(0.4)
                                )
                        }
                        .disabled(!viewModel.canGoPrev)
                        .a11yHitTarget()
                        .accessibilityIdentifier("prevButton")
                        .accessibilityLabel("Chương trước")

                        Button {
                            debounceTask?.cancel()
                            debounceTask = nil
                            beginProgrammaticScrolling()
                            Task {
                                await viewModel.goNext()
                                scrollToTop()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    viewModel.canGoNext
                                        ? DesignTokens.text
                                        : DesignTokens.muted.opacity(0.4)
                                )
                        }
                        .disabled(!viewModel.canGoNext)
                        .a11yHitTarget()
                        .accessibilityIdentifier("nextButton")
                        .accessibilityLabel("Chương sau")
                    }
                    .frame(height: 32)
                    .background(Color(uiColor: .systemGray5).opacity(0.85))
                    .clipShape(Capsule())

                    Button {
                        router.push(.references(bookId: bookId))
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.text)
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .systemGray5).opacity(0.85))
                            .clipShape(Circle())
                    }
                    .a11yHitTarget()
                    .accessibilityIdentifier("tocButton")
                    .accessibilityLabel("Mục lục")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 0)
        .accessibilityIdentifier("header")
    }

    @ViewBuilder
    private var prefetchIndicator: some View {
        if viewModel.prefetchStatus.isRunning {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text(
                    "Đang tải trước \(viewModel.prefetchStatus.processedChapters)/\(viewModel.prefetchStatus.totalChapters)"
                )
                .font(.caption)
                .foregroundStyle(DesignTokens.muted)
            }
            .accessibilityIdentifier("prefetchStatus")
            .padding(.vertical, 4)
        } else if !viewModel.prefetchStatus.errors.isEmpty {
            Text("Tải trước: \(viewModel.prefetchStatus.errors.count) lỗi")
                .font(.caption)
                .foregroundStyle(DesignTokens.error)
                .accessibilityIdentifier("prefetchStatusError")
        }
    }

    private func bottomFloatingBar(_ proxy: ScrollViewProxy) -> some View {
        HStack {
            Spacer()

            Button {
                debounceTask?.cancel()
                debounceTask = nil
                beginProgrammaticScrolling()
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            } label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.text)
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .systemGray5).opacity(0.85))
                    .clipShape(Circle())
            }
            .a11yHitTarget()
            .accessibilityIdentifier("toBottomButton")
            .accessibilityLabel("Cuộn xuống cuối")

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                showSheet = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.text)
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .systemGray5).opacity(0.85))
                    .clipShape(Circle())
            }
            .a11yHitTarget()
            .accessibilityIdentifier("typographyButton")
            .accessibilityLabel("Cài đặt phông chữ")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func handleOffset(_ value: CGFloat) {
        let y = Double(value)
        offsetY = y
        debouncedSave(-y)
        guard !isProgrammaticScrolling else { return }
        let isOverscrolled = ReaderOverscrollLogic.isOverscrolledBeyondBottom(
            offsetY: value,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        )
        if isOverscrolled, !overscrollLock, viewModel.canGoNext {
            overscrollLock = true
            debounceTask?.cancel()
            debounceTask = nil
            beginProgrammaticScrolling()
            Task {
                await viewModel.goNext()
                scrollToTop()
                try? await Task.sleep(nanoseconds: 400_000_000)
                overscrollLock = false
            }
        } else if value > 40, !overscrollLock, viewModel.canGoPrev {
            overscrollLock = true
            debounceTask?.cancel()
            debounceTask = nil
            beginProgrammaticScrolling()
            Task {
                await viewModel.goPrev()
                scrollToTop()
                try? await Task.sleep(nanoseconds: 400_000_000)
                overscrollLock = false
            }
        }
    }

    private func debouncedSave(_ offset: Double) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.saveOffset(offset)
            }
        }
    }

    private func scrollToTop() {
        debounceTask?.cancel()
        debounceTask = nil
        beginProgrammaticScrolling()
        scrollPosition = ScrollPosition(point: .zero)
        if let proxy = scrollProxy {
            withAnimation {
                proxy.scrollTo("top", anchor: .top)
            }
        }
    }

    private func restoreOffset() {
        let session = settingsStore.session
        guard let offset = ReaderOffsetRestore.offsetToRestore(
            sessionBookId: session?.bookId,
            sessionOffset: session?.offset,
            currentBookId: bookId
        ) else { return }
        beginProgrammaticScrolling()
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000)
            await MainActor.run {
                scrollPosition = ScrollPosition(point: CGPoint(x: 0, y: offset))
            }
        }
    }

    private func beginProgrammaticScrolling() {
        isProgrammaticScrolling = true
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                isProgrammaticScrolling = false
            }
        }
    }
}
