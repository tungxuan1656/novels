import SwiftUI

// swiftlint:disable:next type_body_length
struct ReaderView: View {
    let bookId: String
    private let repository: any BookRepository
    @Bindable var router: Router
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ReaderViewModel
    @State private var settingsStore: SettingsStore
    @State private var pendingOffset: Double?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastEdgeSwitch = Date.distantPast
    @State private var showSheet = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var debounceTask: Task<Void, Never>?
    @State private var scrollPosition = ScrollPosition(point: .zero)
    @State private var visibleParagraph: Int?
    @State private var hasOpened = false
    @State private var readyChapter: Int?
    @State private var pendingRestore: ReadingProgress?
    @State private var isJumpingToBottom = false
    @State private var hapticTrigger = 0
    @State private var learningParagraph: BilingualParagraph?
    @State private var speech = ReaderSpeech()

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
        self.repository = repo
        _viewModel = State(initialValue: ReaderViewModel(
            bookId: bookId,
            repository: repo,
            settingsStore: store,
            toastCenter: router.toast,
            prefetchManager: .shared
        ))
        _settingsStore = State(initialValue: store)
    }

    private var theme: ReadingTheme {
        settingsStore.readingTheme
    }

    private var isReaderReady: Bool {
        readyChapter != nil
    }

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.spacing16) {
                            if !isReaderReady || viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else if viewModel.aiMode != .none {
                                aiSection
                            } else if (viewModel.chapterTitle?.isEmpty ?? true) && viewModel.chapterBody.isEmpty {
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
                        #if os(macOS)
                            .frame(maxWidth: 800)
                            .frame(maxWidth: .infinity)
                        #endif
                            .id("top")
                    }
                    .safeAreaPadding(.top, 54)
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .scrollPosition($scrollPosition)
                    .id(viewModel.chapterNumber)
                    .onChange(of: viewModel.chapterNumber) { _, chapter in
                        dismissLearning()
                        if isReaderReady, readyChapter != chapter {
                            readyChapter = chapter
                            pendingRestore = nil
                            scrollToTop()
                            saveChapterStart()
                        }
                    }
                    .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.01) { ids in
                        visibleParagraph = ids.min()
                    }
                    .onScrollGeometryChange(for: Double.self) { geometry in
                        max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                    } action: { _, scrolled in
                        if isJumpingToBottom || scrollPhase == .interacting || scrollPhase == .decelerating {
                            pendingRestore = nil
                            debouncedSave(scrolled)
                        }
                    }
                    .onScrollPhaseChange { _, phase in
                        scrollPhase = phase
                        if phase == .idle {
                            isJumpingToBottom = false
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                handleEdgeSwipe(value: value, width: outer.size.width)
                            }
                    )

                    ReaderHeader(
                        viewModel: viewModel,
                        theme: theme,
                        isReaderReady: isReaderReady,
                        onBack: { router.popReading() },
                        onPrevious: { changeChapter(forward: false) },
                        onNext: { changeChapter(forward: true) },
                        onContents: { router.push(.references(bookId: bookId)) }
                    )

                    if isReaderReady {
                        VStack {
                            Spacer()
                            bottomFloatingBar
                        }
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                // A covered reader can stay mounted when the contents closes.
                .task(id: router.chapterSelectedInContents) {
                    scrollProxy = proxy
                    guard router.chapterSelectedInContents || !isReaderReady else { return }
                    await openReader()
                }
                .onDisappear {
                    dismissLearning()
                    flushPendingOffset()
                    readyChapter = nil
                    viewModel.onDisappear()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase != .active {
                        dismissLearning()
                        flushPendingOffset()
                    }
                }
            }
        }
        .background(theme.background)
        .colorScheme(theme.preferredColorScheme)
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
        #endif
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showSheet) {
                ReaderBottomSheet(settingsStore: settingsStore, viewModel: viewModel, onClose: { showSheet = false })
                    .presentationDetents([.height(560), .large])
                    .preferredColorScheme(theme.preferredColorScheme)
            }
            .sheet(item: $learningParagraph, onDismiss: { speech.stop() }, content: { paragraph in
                EnglishLearningSheet(paragraph: paragraph, theme: theme, speech: speech, settings: settingsStore)
                    .presentationDetents([.medium, .large])
            })
            .onChange(of: isReaderReady) { _, ready in
                if ready {
                    if pendingRestore != nil {
                        restoreProgress()
                    } else {
                        restoreOffset()
                    }
                }
            }
            .onChange(of: viewModel.aiMode) { _, _ in
                pendingRestore = nil
                cancelOffsetSave()
                visibleParagraph = nil
                dismissLearning()
            }
            .onChange(of: viewModel.isAIProcessing) { _, processing in
                if processing {
                    cancelOffsetSave()
                    visibleParagraph = nil
                    dismissLearning()
                } else if pendingRestore != nil {
                    restoreProgress()
                }
            }
    }

    private func dismissLearning() {
        speech.stop()
        learningParagraph = nil
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
            if let paragraphs = viewModel.currentBilingualParagraphs {
                chapterTitleView
                BilingualReaderBody(
                    paragraphs: paragraphs, typography: settingsStore.typography, theme: theme,
                    englishPrimary: settingsStore.bilingualEnglishPrimary,
                    hideOption: settingsStore.bilingualHideOption,
                    onSelect: { learningParagraph = $0 }
                )
            } else if let processed = viewModel.currentProcessedContent, !processed.isEmpty {
                chapterTitleView
                bodyText(processed)
                    .accessibilityIdentifier("aiContent")
            } else if viewModel.isLoading || viewModel.isAIProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if (viewModel.chapterTitle?.isEmpty ?? true) && viewModel.chapterBody.isEmpty {
                Text(viewModel.errorMessage ?? "Không tìm thấy chương")
                    .foregroundStyle(theme.textMuted)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing12) {
            chapterTitleView
            if !viewModel.chapterBody.isEmpty {
                bodyText(viewModel.chapterBody)
            }
        }
    }

    @ViewBuilder
    private var chapterTitleView: some View {
        if let title = viewModel.chapterTitle, !title.isEmpty {
            Text(title)
                .font(ReaderFontMapper.font(
                    name: settingsStore.typography.font,
                    size: CGFloat(settingsStore.typography.fontSize) + 8,
                    weight: .bold
                ))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)
        }
    }

    private func bodyText(_ text: String) -> some View {
        ReaderTextBody(text: text, typography: settingsStore.typography, theme: theme)
    }

    private var bottomFloatingBar: some View {
        HStack {
            Spacer()

            ReaderIconButton(symbol: "arrow.down", theme: theme, size: 24, action: scrollToBottom)
                .accessibilityIdentifier("toBottomButton")
                .accessibilityLabel("Cuộn xuống cuối")
            #if os(iOS)
                .offset(y: 12)
            #endif

            Spacer()
        }
        .overlay(alignment: .trailing) {
            ReaderIconButton(symbol: "textformat.size", theme: theme, iconSize: 13) { showSheet = true }
                .accessibilityIdentifier("typographyButton")
                .accessibilityLabel("Cài đặt phông chữ")
        }
        .padding(.horizontal, 16)
        #if os(macOS)
            .padding(.bottom, 12)
        #else
            .padding(.bottom, -6)
        #endif
    }

    private func handleEdgeSwipe(value: DragGesture.Value, width: CGFloat) {
        let direction = EdgeSwipeDecision.decision(
            startX: value.startLocation.x,
            width: width,
            dx: value.translation.width,
            dy: value.translation.height
        )
        guard isReaderReady, let direction else { return }
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
        hapticTrigger += 1
        changeChapter(forward: false, now: now)
    }

    private func edgeGoNext(now: Date) {
        guard viewModel.canGoNext else {
            router.toast.show("Đã là chương cuối", type: .info)
            return
        }
        hapticTrigger += 1
        changeChapter(forward: true, now: now)
    }

    private func changeChapter(forward: Bool, now: Date = .now) {
        lastEdgeSwitch = now
        cancelOffsetSave()
        Task {
            if forward {
                await viewModel.goNext()
            } else {
                await viewModel.goPrev()
            }
        }
    }

    private func openReader() async {
        let selectedChapter = router.chapterSelectedInContents
        if selectedChapter {
            cancelOffsetSave()
        }
        if !hasOpened, !selectedChapter {
            let saved = await ReadingProgressStore.shared.progressOnOpen(bookId: bookId)
            guard !Task.isCancelled else { return }
            if let saved {
                useSavedProgress(saved.progress, isLocal: saved.isLocal)
            }
        }
        hasOpened = true
        let disappearingChapter = viewModel.lastVisibleChapter
        let disappearingMode = viewModel.lastVisibleMode
        viewModel.onAppear()
        let source: LoadSource = disappearingChapter == viewModel.chapterNumber && disappearingMode == viewModel.aiMode
            ? .returnFromLog : .chapterChange
        await viewModel.load(source: source)
        guard !Task.isCancelled else { return }
        readyChapter = viewModel.chapterNumber
        if selectedChapter {
            pendingRestore = nil
            scrollToTop()
            router.chapterSelectedInContents = false
        }
    }

    private func useSavedProgress(_ progress: ReadingProgress, isLocal: Bool) {
        guard let count = (try? repository.book(slug: bookId))?.count,
              progress.fits(chapterCount: count) else { return }
        let session = settingsStore.session
        let hasLocalOffset = session?.bookId == bookId && session?.chapterNumber == progress.chapter
            && (session?.offset ?? 0) > 0
        guard !isLocal || !hasLocalOffset else { return }
        pendingRestore = progress
        settingsStore.session?.chapterNumber = progress.chapter
        settingsStore.session?.offset = 0
    }

    private func restoreProgress() {
        guard isReaderReady, !viewModel.isAIProcessing, let progress = pendingRestore else { return }
        pendingRestore = nil
        guard progress.chapter == viewModel.chapterNumber, let anchor = progress.anchor,
              let layout = readingLayout(), let index = anchor.index(in: layout.rendition, count: layout.count)
        else { return }
        scrollPosition.scrollTo(id: index, anchor: .top)
    }

    private func readingLayout() -> (rendition: String, count: Int)? {
        if let paragraphs = viewModel.currentBilingualParagraphs {
            let text = paragraphs.map { "\($0.vi)\u{1E}\($0.en)" }.joined(separator: "\u{1F}")
            return ("bilingual-v1-" + SHA256.hex(text), paragraphs.count)
        }
        if let text = viewModel.currentProcessedContent {
            return ("processed-v1-" + SHA256.hex(text), ReaderBodySplitter.split(text).count)
        }
        guard !viewModel.isAIProcessing, !viewModel.chapterBody.isEmpty else { return nil }
        return ("raw-v1-" + SHA256.hex(viewModel.chapterBody), ReaderBodySplitter.split(viewModel.chapterBody).count)
    }

    private func saveReadingPosition(_ offset: Double) {
        guard readyChapter == viewModel.chapterNumber, let layout = readingLayout() else { return }
        viewModel.saveOffset(offset)
        if offset <= 1 {
            ReadingProgressStore.shared.save(bookId: bookId, chapter: viewModel.chapterNumber, anchor: nil)
        } else if let index = visibleParagraph, (0 ..< layout.count).contains(index) {
            let anchor = ReadingProgress.Anchor(rendition: layout.rendition, paragraph: index)
            ReadingProgressStore.shared.save(bookId: bookId, chapter: viewModel.chapterNumber, anchor: anchor)
        }
    }

    private func saveChapterStart() {
        guard viewModel.errorMessage == nil else { return }
        ReadingProgressStore.shared.save(bookId: bookId, chapter: viewModel.chapterNumber, anchor: nil)
    }

    private func debouncedSave(_ offset: Double) {
        guard isReaderReady, !viewModel.isLoading, !viewModel.isAIProcessing else { return }
        debounceTask?.cancel()
        pendingOffset = offset
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            flushPendingOffset()
        }
    }

    private func flushPendingOffset() {
        if let pendingOffset {
            saveReadingPosition(pendingOffset)
        }
        cancelOffsetSave()
    }

    private func cancelOffsetSave() {
        debounceTask?.cancel()
        debounceTask = nil
        pendingOffset = nil
    }

    private func scrollToTop() {
        cancelOffsetSave()
        isJumpingToBottom = false
        visibleParagraph = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPosition = ScrollPosition(point: .zero)
            scrollProxy?.scrollTo("top", anchor: .top)
        }
    }

    private func scrollToBottom() {
        cancelOffsetSave()
        pendingRestore = nil
        isJumpingToBottom = true
        withAnimation(.easeOut(duration: 0.35)) {
            scrollPosition.scrollTo(edge: .bottom)
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
                let hasTitle = !(viewModel.chapterTitle?.isEmpty ?? true)
                let hasContent = hasTitle || !viewModel.chapterBody.isEmpty || viewModel.errorMessage != nil
                guard !viewModel.isLoading, hasContent else { return }
                scrollPosition = ScrollPosition(point: CGPoint(x: 0, y: offset))
            }
        }
    }
}
