import SwiftUI

// swiftlint:disable:next type_body_length
struct ReaderView: View {
    let bookId: String
    @Bindable var router: Router
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ReaderViewModel
    @State private var settingsStore: SettingsStore
    @State private var currentOffset: Double = 0
    @State private var lastEdgeSwitch = Date.distantPast
    @State private var showSheet = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var debounceTask: Task<Void, Never>?
    @State private var scrollPosition = ScrollPosition(point: .zero)
    @State private var hapticTrigger = 0

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

    private var theme: ReadingTheme {
        settingsStore.readingTheme
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
                                    .foregroundStyle(theme.textMuted)
                            } else {
                                content
                            }
                            Color.clear
                                .frame(height: 120)
                                .id("bottom")
                        }
                        .padding(DesignTokens.spacing16)
                        .id("top")
                    }
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .scrollPosition($scrollPosition)
                    .onChange(of: viewModel.chapterNumber) { _, _ in
                        scrollToTop()
                    }
                    .onScrollGeometryChange(for: Double.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, scrolled in
                        currentOffset = scrolled
                        debouncedSave(scrolled)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                handleEdgeSwipe(value: value, width: outer.size.width)
                            }
                    )

                    topHeader

                    VStack {
                        Spacer()
                        bottomFloatingBar(proxy)
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .onAppear {
                    scrollProxy = proxy
                    let disappearingChapter = viewModel.lastVisibleChapter
                    let disappearingMode = viewModel.lastVisibleMode
                    viewModel.onAppear()
                    let source: LoadSource =
                        (disappearingChapter == viewModel.chapterNumber
                            && disappearingMode == viewModel.aiMode)
                        ? .returnFromLog : .chapterChange
                    Task {
                        await viewModel.load(source: source)
                        restoreOffset()
                    }
                }
                .onDisappear {
                    flushPendingOffset()
                    viewModel.onDisappear()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Kill within the 300ms debounce window must not lose position:
                    // persist the latest offset synchronously on backgrounding.
                    if newPhase == .background {
                        flushPendingOffset()
                    }
                }
            }
        }
        .background(theme.background)
        .colorScheme(theme.preferredColorScheme)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showSheet) {
            ReaderBottomSheet(settingsStore: settingsStore, viewModel: viewModel, onClose: { showSheet = false })
                .presentationDetents([.height(600), .large])
                .presentationBackground(.ultraThinMaterial)
                .preferredColorScheme(theme.preferredColorScheme)
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
            if let processed = viewModel.currentProcessedContent, !processed.isEmpty {
                aiProcessedContent(processed)
            } else if viewModel.isLoading || viewModel.isAIProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.blocks.isEmpty {
                Text(viewModel.errorMessage ?? "Không tìm thấy chương")
                    .foregroundStyle(theme.textMuted)
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
                        return accumulator + Text(span.text)
                    }
                    var piece = Text(span.text)
                        .font(fontFor(block: block, span: span))
                        .foregroundStyle(theme.textPrimary)
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
        let base = CGFloat(settingsStore.typography.fontSize)
        let fontName = settingsStore.typography.font
        let font = ReaderFontMapper.font(name: fontName, size: base)

        return Text(text)
            .font(font)
            .foregroundStyle(theme.textPrimary)
            .lineSpacing(CGFloat(settingsStore.typography.lineHeight))
            .kerning(CGFloat(settingsStore.typography.letterSpacing))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("aiContent")
    }

    private func fontFor(block: TextBlock, span: TextSpan) -> Font {
        let base = CGFloat(settingsStore.typography.fontSize)
        let fontName = settingsStore.typography.font

        if block.isHeading {
            let level = CGFloat(block.headingLevel ?? 3)
            let size = base + CGFloat(7 - level) * 2
            return ReaderFontMapper.font(name: fontName, size: size, weight: .bold)
        }
        return ReaderFontMapper.font(name: fontName, size: base)
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
        VStack(spacing: 0) {
            HStack {
                Text(topChapterTitleText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("chapterText")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background(theme.headerBackground)

            HStack {
                Button {
                    router.popReading()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.iconTint)
                        .frame(width: 28, height: 28)
                        .background(theme.chipBackground)
                        .clipShape(Circle())
                }
                .a11yHitTarget()
                .accessibilityIdentifier("backButton")
                .accessibilityLabel("Quay lại Thư viện")

                Spacer()

                HStack(spacing: 4) {
                    if viewModel.isAIProcessing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 22, height: 28)
                            Text("Đang xử lý")
                                .font(.caption)
                                .foregroundStyle(theme.textMuted)
                                .lineLimit(1)
                        }
                        .frame(height: 28)
                        .accessibilityIdentifier("aiProgressHeader")
                        .accessibilityLabel("Đang xử lý")
                    }
                    HStack(spacing: 2) {
                        Button {
                            debounceTask?.cancel()
                            debounceTask = nil
                            lastEdgeSwitch = Date()
                            Task {
                                await viewModel.goPrev()
                                scrollToTop()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    viewModel.canGoPrev
                                        ? theme.iconTint
                                        : theme.iconTint.opacity(theme.disabledIconOpacity)
                                )
                                .frame(width: 22, height: 28)
                                .contentShape(Rectangle())
                        }
                        .disabled(!viewModel.canGoPrev)
                        .accessibilityIdentifier("prevButton")
                        .accessibilityLabel("Chương trước")

                        Button {
                            debounceTask?.cancel()
                            debounceTask = nil
                            lastEdgeSwitch = Date()
                            Task {
                                await viewModel.goNext()
                                scrollToTop()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    viewModel.canGoNext
                                        ? theme.iconTint
                                        : theme.iconTint.opacity(theme.disabledIconOpacity)
                                )
                                .frame(width: 22, height: 28)
                                .contentShape(Rectangle())
                        }
                        .disabled(!viewModel.canGoNext)
                        .accessibilityIdentifier("nextButton")
                        .accessibilityLabel("Chương sau")
                    }
                    .padding(.horizontal, 2)
                    .frame(height: 28)
                    .background(theme.chipBackground)
                    .clipShape(Capsule())

                    Button {
                        router.push(.references(bookId: bookId))
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.iconTint)
                            .frame(width: 28, height: 28)
                            .background(theme.chipBackground)
                            .clipShape(Circle())
                    }
                    .a11yHitTarget()
                    .accessibilityIdentifier("tocButton")
                    .accessibilityLabel("Mục lục")
                }
            }
            .padding(.horizontal, 8)
        }
        .accessibilityIdentifier("header")
    }

    private func bottomFloatingBar(_ proxy: ScrollViewProxy) -> some View {
        HStack {
            Spacer()

            Button {
                scrollToBottom()
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.iconTint)
                    .frame(width: 24, height: 24)
                    .background(theme.chipBackground)
                    .clipShape(Circle())
            }
            .a11yHitTarget()
            .accessibilityIdentifier("toBottomButton")
            .accessibilityLabel("Cuộn xuống cuối")
            .offset(y: 12)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                showSheet = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.iconTint)
                    .frame(width: 28, height: 28)
                    .background(theme.chipBackground)
                    .clipShape(Circle())
            }
            .a11yHitTarget()
            .accessibilityIdentifier("typographyButton")
            .accessibilityLabel("Cài đặt phông chữ")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, -6)
    }

    private func handleEdgeSwipe(value: DragGesture.Value, width: CGFloat) {
        let direction = EdgeSwipeDecision.decision(
            startX: value.startLocation.x,
            width: width,
            dx: value.translation.width,
            dy: value.translation.height
        )
        guard let direction else { return }
        let now = Date()
        guard EdgeSwipeDecision.isThrottleOk(now: now, lastSwitch: lastEdgeSwitch) else { return }
        // swiftlint:disable switch_case_alignment
        switch direction {
            case .prev:
                edgeGoPrev(now: now)
            case .next:
                edgeGoNext(now: now)
        }
        // swiftlint:enable switch_case_alignment
    }

    private func edgeGoPrev(now: Date) {
        guard viewModel.canGoPrev else {
            router.toast.show("Đã là chương đầu", type: .info)
            return
        }
        lastEdgeSwitch = now
        debounceTask?.cancel()
        debounceTask = nil
        hapticTrigger += 1
        Task {
            await viewModel.goPrev()
            scrollToTop()
        }
    }

    private func edgeGoNext(now: Date) {
        guard viewModel.canGoNext else {
            router.toast.show("Đã là chương cuối", type: .info)
            return
        }
        lastEdgeSwitch = now
        debounceTask?.cancel()
        debounceTask = nil
        hapticTrigger += 1
        Task {
            await viewModel.goNext()
            scrollToTop()
        }
    }

    private func debouncedSave(_ offset: Double) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.saveOffset(offset)
                debounceTask = nil
            }
        }
    }

    /// Synchronously persist the latest scroll offset when a debounced save is
    /// still pending. Called from onDisappear and scenePhase background so a
    /// kill inside the 300ms debounce window cannot lose the position.
    private func flushPendingOffset() {
        if debounceTask != nil {
            viewModel.saveOffset(currentOffset)
        }
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func scrollToTop() {
        debounceTask?.cancel()
        debounceTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPosition = ScrollPosition(point: .zero)
            scrollProxy?.scrollTo("top", anchor: .top)
        }
    }

    private func scrollToBottom() {
        debounceTask?.cancel()
        debounceTask = nil
        if let proxy = scrollProxy {
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo("bottom", anchor: .bottom)
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
        // Top of chapter needs no scroll work: position already starts at zero.
        guard ReaderRestoreDecision.needsScrollRestore(offset: offset) else { return }
        let chapter = viewModel.chapterNumber
        Task {
            // Content is ready (called after await load()), so a single ready
            // check suffices before the single scroll assign.
            await MainActor.run {
                // Never apply a stale restore onto a chapter the user already left.
                guard viewModel.chapterNumber == chapter else { return }
                guard !viewModel.isLoading, !viewModel.blocks.isEmpty || viewModel.errorMessage != nil else { return }
                scrollPosition = ScrollPosition(point: CGPoint(x: 0, y: offset))
            }
        }
    }
}

/// Pure helper for scroll-restore decision — testable without UI.
enum ReaderRestoreDecision {
    /// Top-of-chapter (or missing) offsets need no scroll work.
    static func needsScrollRestore(offset: Double?) -> Bool {
        (offset ?? 0) > 0
    }
}
