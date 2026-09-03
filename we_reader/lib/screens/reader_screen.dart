import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../providers/reader_settings.dart';
import '../reader/pagination.dart';
import '../reader/sentence_splitter.dart';
import '../reader/span_builder.dart';
import '../reader/tts_controller.dart';

/// 阅读器：分页 / 滚动两种模式，主题、字号、目录、进度、
/// 划线 / 想法 / 书签，以及 TTS 听书（当前句高亮）。
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.autoStartTts = false,
  });

  final Book book;
  final int? initialChapterIndex;
  final bool autoStartTts;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _ReaderPanel { none, font, theme }

const double _kHeaderHeight = 30;
const double _kFooterHeight = 26;
const double _kHorizontalPadding = 24;
const double _kVerticalPadding = 8;

class _ReaderScreenState extends State<ReaderScreen> {
  List<Chapter>? _chapters;
  List<int> _charsBefore = [];
  int _totalChars = 1;

  List<PageSpec> _pages = [];
  (double, double, double, double)? _paginationKey;
  Size _contentSize = Size.zero;
  PageController? _pageController;
  int _currentPageIndex = 0;

  /// 当前位置（两种翻页模式共用的“真实进度”）。
  int _chapterIndex = 0;
  int _charOffset = 0;

  bool _menuVisible = false;
  _ReaderPanel _panel = _ReaderPanel.none;

  late final TtsController _tts;
  final ScrollController _scrollController = ScrollController();
  final Stopwatch _stopwatch = Stopwatch()..start();
  AppState? _appState;
  bool _autoTtsStarted = false;
  bool _shelfPrompted = false;

  @override
  void initState() {
    super.initState();
    _tts = TtsController()
      ..onSentenceChanged = _onTtsSentence
      ..onBookFinished = () {
        if (mounted) setState(() => _menuVisible = true);
      };
    _loadChapters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    _saveProgress();
    _appState?.addReadingSeconds(_stopwatch.elapsed.inSeconds);
    _tts.dispose();
    _pageController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    final chapters = await BookRepository.instance.loadChapters(widget.book);
    final charsBefore = <int>[];
    var total = 0;
    for (final chapter in chapters) {
      charsBefore.add(total);
      total += chapter.content.length;
    }

    var chapterIndex = 0;
    var charOffset = 0;
    if (widget.initialChapterIndex != null) {
      chapterIndex = widget.initialChapterIndex!.clamp(0, chapters.length - 1);
    } else {
      final progress = _appState?.progressOf(widget.book.id);
      if (progress != null && progress.chapterIndex < chapters.length) {
        chapterIndex = progress.chapterIndex;
        charOffset = progress.charOffset;
      }
    }

    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _charsBefore = charsBefore;
      _totalChars = total == 0 ? 1 : total;
      _chapterIndex = chapterIndex;
      _charOffset = charOffset;
    });
  }

  // ---------- 分页 ----------

  TextStyle _contentStyle(ReaderSettings settings) => TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        color: settings.colors.text,
      );

  void _ensurePagination(ReaderSettings settings, BoxConstraints constraints) {
    final contentSize = Size(
      constraints.maxWidth - _kHorizontalPadding * 2,
      constraints.maxHeight -
          _kHeaderHeight -
          _kFooterHeight -
          _kVerticalPadding * 2,
    );
    final key = (
      contentSize.width,
      contentSize.height,
      settings.fontSize,
      settings.lineHeight,
    );
    if (key == _paginationKey) return;

    _paginationKey = key;
    _contentSize = contentSize;
    _pages = Paginator.paginateBook(
      chapters: _chapters!,
      style: _contentStyle(settings),
      pageSize: contentSize,
    );
    _currentPageIndex = _pageIndexFor(_chapterIndex, _charOffset);
    _replacePageController(_currentPageIndex);

    if (widget.autoStartTts && !_autoTtsStarted) {
      _autoTtsStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTts());
    }
  }

  void _replacePageController(int initialPage) {
    final old = _pageController;
    _pageController = PageController(initialPage: initialPage);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  int _pageIndexFor(int chapterIndex, int charOffset) {
    var candidate = 0;
    for (var i = 0; i < _pages.length; i++) {
      final page = _pages[i];
      if (page.chapterIndex < chapterIndex) {
        candidate = i;
      } else if (page.chapterIndex == chapterIndex) {
        candidate = i;
        if (page.containsOffset(charOffset) || page.start >= charOffset) {
          return i;
        }
      }
    }
    return candidate;
  }

  // ---------- 进度 ----------

  double get _percent {
    if (_chapters == null || _chapters!.isEmpty) return 0;
    final endOffset = _isSlideMode && _pages.isNotEmpty
        ? _pages[_currentPageIndex.clamp(0, _pages.length - 1)].end
        : _charOffset;
    final chapterBase = _charsBefore[_chapterIndex.clamp(
      0,
      _charsBefore.length - 1,
    )];
    return ((chapterBase + endOffset) / _totalChars).clamp(0.0, 1.0);
  }

  bool get _isSlideMode =>
      context.read<ReaderSettings>().pageTurnMode == PageTurnMode.slide;

  void _saveProgress() {
    if (_chapters == null) return;
    _appState?.saveProgress(ReadingProgress(
      bookId: widget.book.id,
      chapterIndex: _chapterIndex,
      charOffset: _charOffset,
      percent: _percent,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // ---------- 跳转 ----------

  void _jumpToPage(int index) {
    if (_pages.isEmpty) return;
    final target = index.clamp(0, _pages.length - 1);
    final page = _pages[target];
    setState(() {
      _currentPageIndex = target;
      _chapterIndex = page.chapterIndex;
      _charOffset = page.start;
    });
    _pageController?.jumpToPage(target);
    _saveProgress();
  }

  void _jumpToChapter(int chapterIndex, {int offset = 0}) {
    if (_chapters == null) return;
    final target = chapterIndex.clamp(0, _chapters!.length - 1);
    if (_isSlideMode) {
      _jumpToPage(_pageIndexFor(target, offset));
    } else {
      setState(() {
        _chapterIndex = target;
        _charOffset = offset;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final content = _chapters![target].content;
        final fraction =
            content.isEmpty ? 0.0 : (offset / content.length).clamp(0.0, 1.0);
        _scrollController
            .jumpTo(_scrollController.position.maxScrollExtent * fraction);
      });
      _saveProgress();
    }
  }

  // ---------- TTS ----------

  void _startTts() {
    final settings = context.read<ReaderSettings>();
    setState(() {
      _menuVisible = false;
      _panel = _ReaderPanel.none;
    });
    _tts.start(
      chapters: _chapters!,
      chapterIndex: _chapterIndex,
      fromOffset: _charOffset,
      rate: settings.ttsRate,
    );
  }

  void _onTtsSentence(int chapterIndex, Sentence sentence) {
    if (!mounted) return;
    _chapterIndex = chapterIndex;
    _charOffset = sentence.start;
    if (_isSlideMode) {
      final target = _pageIndexFor(chapterIndex, sentence.start);
      if (target != _currentPageIndex) {
        _currentPageIndex = target;
        _pageController?.animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final content = _chapters![chapterIndex].content;
        final fraction = content.isEmpty
            ? 0.0
            : (sentence.start / content.length).clamp(0.0, 1.0);
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent * fraction,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  // ---------- 标注 ----------

  void _createAnnotation({
    required int chapterIndex,
    required int baseOffset,
    required TextSelection selection,
    String? note,
  }) {
    if (!selection.isValid || selection.isCollapsed) return;
    final chapter = _chapters![chapterIndex];
    final start = (baseOffset + selection.start)
        .clamp(0, chapter.content.length);
    final end = (baseOffset + selection.end).clamp(0, chapter.content.length);
    if (start >= end) return;

    _appState?.addAnnotation(Annotation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookId: widget.book.id,
      chapterIndex: chapterIndex,
      start: start,
      end: end,
      type: note == null ? AnnotationType.highlight : AnnotationType.note,
      selectedText: chapter.content.substring(start, end),
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(note == null ? '已划线' : '已保存想法'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _promptNote({
    required int chapterIndex,
    required int baseOffset,
    required TextSelection selection,
  }) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('写想法'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '写下这一刻的想法…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && note.isNotEmpty) {
      _createAnnotation(
        chapterIndex: chapterIndex,
        baseOffset: baseOffset,
        selection: selection,
        note: note,
      );
    }
  }

  void _toggleBookmark() {
    if (_chapters == null || _appState == null) return;
    final int start;
    final int end;
    if (_isSlideMode && _pages.isNotEmpty) {
      final page = _pages[_currentPageIndex.clamp(0, _pages.length - 1)];
      start = page.start;
      end = page.end > page.start ? page.end : page.start + 1;
    } else {
      start = 0;
      end = _chapters![_chapterIndex].content.length + 1;
    }
    final existing =
        _appState!.bookmarkAt(widget.book.id, _chapterIndex, start, end);
    if (existing != null) {
      _appState!.removeAnnotation(existing.id);
    } else {
      final chapter = _chapters![_chapterIndex];
      final excerptEnd =
          (start + 20).clamp(0, chapter.content.length);
      _appState!.addAnnotation(Annotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: widget.book.id,
        chapterIndex: _chapterIndex,
        start: start,
        end: start,
        type: AnnotationType.bookmark,
        selectedText: chapter.content.substring(
          start.clamp(0, chapter.content.length),
          excerptEnd,
        ),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Annotation? get _currentBookmark {
    if (_chapters == null || _appState == null) return null;
    if (_isSlideMode && _pages.isNotEmpty) {
      final page = _pages[_currentPageIndex.clamp(0, _pages.length - 1)];
      return _appState!.bookmarkAt(
        widget.book.id,
        _chapterIndex,
        page.start,
        page.end > page.start ? page.end : page.start + 1,
      );
    }
    return _appState!.bookmarkAt(
      widget.book.id,
      _chapterIndex,
      0,
      _chapters![_chapterIndex].content.length + 1,
    );
  }

  // ---------- 交互 ----------

  void _handleTapZone(double dx, double width) {
    if (_menuVisible || _panel != _ReaderPanel.none) {
      setState(() {
        _menuVisible = false;
        _panel = _ReaderPanel.none;
      });
      return;
    }
    if (_isSlideMode && !_tts.isActive) {
      if (dx < width / 3) {
        _jumpToPage(_currentPageIndex - 1);
        return;
      }
      if (dx > width * 2 / 3) {
        _jumpToPage(_currentPageIndex + 1);
        return;
      }
    }
    setState(() => _menuVisible = true);
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final appState = _appState;
    if (appState == null || appState.isOnShelf(widget.book.id)) {
      _shelfPrompted = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('加入书架'),
        content: Text('喜欢《${widget.book.title}》就加入书架，方便下次继续阅读。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('加入书架'),
          ),
        ],
      ),
    );
    if (add == true) appState.addToShelf(widget.book.id);
    _shelfPrompted = true;
    if (mounted) Navigator.of(context).pop();
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ReaderSettings>();
    final colors = settings.colors;

    if (_chapters == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final canPopDirectly =
        _shelfPrompted || (_appState?.isOnShelf(widget.book.id) ?? false);

    return PopScope(
      canPop: canPopDirectly,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _ensurePagination(settings, constraints);
              return ListenableBuilder(
                listenable: _tts,
                builder: (context, _) => Stack(
                  children: [
                    Positioned.fill(
                      child: settings.pageTurnMode == PageTurnMode.slide
                          ? _buildPageView(settings)
                          : _buildScrollView(settings),
                    ),
                    _buildTopMenu(colors),
                    _buildBottomMenu(settings),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- 左右翻页模式 ----------

  Widget _buildPageView(ReaderSettings settings) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        final page = _pages[index];
        setState(() {
          _currentPageIndex = index;
          _chapterIndex = page.chapterIndex;
          _charOffset = page.start;
        });
        _saveProgress();
      },
      itemBuilder: (context, index) => _buildPage(settings, index),
    );
  }

  Widget _buildPage(ReaderSettings settings, int index) {
    final colors = settings.colors;
    final page = _pages[index];
    final chapter = _chapters![page.chapterIndex];
    final text = chapter.content.substring(page.start, page.end);
    final annotations = context
        .watch<AppState>()
        .annotationsOf(widget.book.id)
        .where((a) => a.chapterIndex == page.chapterIndex)
        .toList();
    final ttsRange = _tts.isActive && _tts.chapterIndex == page.chapterIndex
        ? _tts.currentRange
        : null;
    final spans = buildAnnotatedSpans(
      text: text,
      baseOffset: page.start,
      style: _contentStyle(settings),
      annotations: annotations,
      ttsRange: ttsRange,
      colors: colors,
    );

    final metaStyle = TextStyle(fontSize: 11, color: colors.secondaryText);
    final chapterPages =
        _pages.where((p) => p.chapterIndex == page.chapterIndex).toList();
    final pageInChapter = chapterPages.indexOf(page) + 1;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) =>
          _handleTapZone(details.localPosition.dx, _contentSize.width),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kHorizontalPadding,
          vertical: _kVerticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _kHeaderHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ),
            ),
            SizedBox(
              width: _contentSize.width,
              height: _contentSize.height,
              child: Align(
                alignment: Alignment.topLeft,
                child: _buildRichText(
                  spans: spans,
                  chapterIndex: page.chapterIndex,
                  baseOffset: page.start,
                ),
              ),
            ),
            SizedBox(
              height: _kFooterHeight,
              child: Row(
                children: [
                  Text('$pageInChapter/${chapterPages.length}',
                      style: metaStyle),
                  const Spacer(),
                  Text('${(_percentAtPage(index) * 100).toStringAsFixed(1)}%',
                      style: metaStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _percentAtPage(int index) {
    final page = _pages[index];
    return ((_charsBefore[page.chapterIndex] + page.end) / _totalChars)
        .clamp(0.0, 1.0);
  }

  // ---------- 上下滚动模式 ----------

  Widget _buildScrollView(ReaderSettings settings) {
    final colors = settings.colors;
    final chapter = _chapters![_chapterIndex];
    final annotations = context
        .watch<AppState>()
        .annotationsOf(widget.book.id)
        .where((a) => a.chapterIndex == _chapterIndex)
        .toList();
    final ttsRange = _tts.isActive && _tts.chapterIndex == _chapterIndex
        ? _tts.currentRange
        : null;
    final spans = buildAnnotatedSpans(
      text: chapter.content,
      baseOffset: 0,
      style: _contentStyle(settings),
      annotations: annotations,
      ttsRange: ttsRange,
      colors: colors,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) =>
          _handleTapZone(details.localPosition.dx, _contentSize.width),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final position = _scrollController.position;
          final fraction = position.maxScrollExtent == 0
              ? 0.0
              : (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
          _charOffset = (chapter.content.length * fraction).round();
          _saveProgress();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: _kHorizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                style: TextStyle(
                  fontSize: settings.fontSize + 4,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              _buildRichText(
                spans: spans,
                chapterIndex: _chapterIndex,
                baseOffset: 0,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _chapterIndex > 0
                        ? () => _jumpToChapter(_chapterIndex - 1)
                        : null,
                    child: const Text('上一章'),
                  ),
                  Text(
                    '${_chapterIndex + 1} / ${_chapters!.length}',
                    style:
                        TextStyle(fontSize: 12, color: colors.secondaryText),
                  ),
                  TextButton(
                    onPressed: _chapterIndex < _chapters!.length - 1
                        ? () => _jumpToChapter(_chapterIndex + 1)
                        : null,
                    child: const Text('下一章'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 正文文本：听书时用不可选中的 RichText，否则用可划线的 SelectableText。
  Widget _buildRichText({
    required List<TextSpan> spans,
    required int chapterIndex,
    required int baseOffset,
  }) {
    if (_tts.isActive) {
      return Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
      );
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
      onTap: () => _handleTapZone(_contentSize.width / 2, _contentSize.width),
      contextMenuBuilder: (menuContext, editableTextState) {
        final selection = editableTextState.textEditingValue.selection;
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: [
            ContextMenuButtonItem(
              label: '复制',
              onPressed: () {
                editableTextState.copySelection(SelectionChangedCause.toolbar);
              },
            ),
            ContextMenuButtonItem(
              label: '划线',
              onPressed: () {
                editableTextState.hideToolbar();
                _createAnnotation(
                  chapterIndex: chapterIndex,
                  baseOffset: baseOffset,
                  selection: selection,
                );
              },
            ),
            ContextMenuButtonItem(
              label: '写想法',
              onPressed: () {
                editableTextState.hideToolbar();
                _promptNote(
                  chapterIndex: chapterIndex,
                  baseOffset: baseOffset,
                  selection: selection,
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ---------- 顶部菜单 ----------

  Widget _buildTopMenu(ReaderThemeColors colors) {
    final menuColor = colors.brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : Colors.white;
    final bookmark = _currentBookmark;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      top: _menuVisible ? 0 : -64,
      left: 0,
      right: 0,
      child: Container(
        height: 56,
        color: menuColor,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 20, color: colors.text),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: colors.text),
              ),
            ),
            IconButton(
              icon: Icon(
                bookmark != null ? Icons.bookmark : Icons.bookmark_border,
                color: bookmark != null
                    ? Theme.of(context).colorScheme.primary
                    : colors.text,
              ),
              onPressed: () => setState(_toggleBookmark),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 底部菜单 ----------

  Widget _buildBottomMenu(ReaderSettings settings) {
    final colors = settings.colors;
    final menuColor = colors.brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : Colors.white;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      bottom: _menuVisible ? 0 : -320,
      left: 0,
      right: 0,
      child: Container(
        color: menuColor,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_panel == _ReaderPanel.font) _buildFontPanel(settings),
            if (_panel == _ReaderPanel.theme) _buildThemePanel(settings),
            if (_tts.isActive)
              _buildTtsBar(settings)
            else ...[
              _buildProgressRow(settings),
              _buildActionRow(settings),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(ReaderSettings settings) {
    final colors = settings.colors;
    if (settings.pageTurnMode == PageTurnMode.scroll || _pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            TextButton(
              onPressed: _chapterIndex > 0
                  ? () => _jumpToChapter(_chapterIndex - 1)
                  : null,
              child: const Text('上一章'),
            ),
            Expanded(
              child: Text(
                _chapters![_chapterIndex].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.text),
              ),
            ),
            TextButton(
              onPressed: _chapterIndex < _chapters!.length - 1
                  ? () => _jumpToChapter(_chapterIndex + 1)
                  : null,
              child: const Text('下一章'),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          color: colors.text,
          tooltip: '上一章',
          onPressed: _chapterIndex > 0
              ? () => _jumpToChapter(_chapterIndex - 1)
              : null,
        ),
        Expanded(
          child: Slider(
            value: _currentPageIndex
                .clamp(0, _pages.length - 1)
                .toDouble(),
            max: (_pages.length - 1).toDouble(),
            onChanged: (value) => _jumpToPage(value.round()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          color: colors.text,
          tooltip: '下一章',
          onPressed: _chapterIndex < _chapters!.length - 1
              ? () => _jumpToChapter(_chapterIndex + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildActionRow(ReaderSettings settings) {
    final colors = settings.colors;

    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: colors.text),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: colors.text),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(Icons.list, '目录', _showTocSheet),
        action(Icons.headphones, '听书', _startTts),
        action(
          settings.theme == ReaderTheme.night
              ? Icons.dark_mode
              : Icons.light_mode,
          '主题',
          () => setState(() {
            _panel = _panel == _ReaderPanel.theme
                ? _ReaderPanel.none
                : _ReaderPanel.theme;
          }),
        ),
        action(
          Icons.text_fields,
          '字号',
          () => setState(() {
            _panel = _panel == _ReaderPanel.font
                ? _ReaderPanel.none
                : _ReaderPanel.font;
          }),
        ),
      ],
    );
  }

  Widget _buildFontPanel(ReaderSettings settings) {
    final colors = settings.colors;
    final labelStyle = TextStyle(fontSize: 13, color: colors.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text('字号', style: labelStyle),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.remove),
                color: colors.text,
                onPressed: () => settings.fontSize = settings.fontSize - 1,
              ),
              Expanded(
                child: Slider(
                  value: settings.fontSize,
                  min: ReaderSettings.minFontSize,
                  max: ReaderSettings.maxFontSize,
                  onChanged: (value) => settings.fontSize = value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                color: colors.text,
                onPressed: () => settings.fontSize = settings.fontSize + 1,
              ),
              Text(settings.fontSize.round().toString(), style: labelStyle),
            ],
          ),
          Row(
            children: [
              Text('行距', style: labelStyle),
              const SizedBox(width: 12),
              for (final (label, value) in const [
                ('紧凑', 1.5),
                ('适中', 1.8),
                ('宽松', 2.2),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: (settings.lineHeight - value).abs() < 0.01,
                    showCheckmark: false,
                    onSelected: (_) => settings.lineHeight = value,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('翻页', style: labelStyle),
              const SizedBox(width: 12),
              SegmentedButton<PageTurnMode>(
                segments: const [
                  ButtonSegment(
                    value: PageTurnMode.slide,
                    label: Text('左右翻页'),
                  ),
                  ButtonSegment(
                    value: PageTurnMode.scroll,
                    label: Text('上下滚动'),
                  ),
                ],
                selected: {settings.pageTurnMode},
                onSelectionChanged: (selection) {
                  final mode = selection.first;
                  settings.pageTurnMode = mode;
                  if (mode == PageTurnMode.slide) {
                    _currentPageIndex =
                        _pageIndexFor(_chapterIndex, _charOffset);
                    _replacePageController(_currentPageIndex);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemePanel(ReaderSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (theme, label) in const [
            (ReaderTheme.day, '日间'),
            (ReaderTheme.eyeCare, '护眼'),
            (ReaderTheme.night, '夜间'),
          ])
            GestureDetector(
              onTap: () => settings.theme = theme,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: readerThemeColors[theme]!.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 2,
                        color: settings.theme == theme
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: readerThemeColors[theme]!.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: settings.colors.text,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- TTS 控制栏 ----------

  Widget _buildTtsBar(ReaderSettings settings) {
    final colors = settings.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '正在朗读 · ${_chapters![_tts.chapterIndex].title}',
            style: TextStyle(fontSize: 12, color: colors.secondaryText),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final rate in const [0.75, 1.0, 1.25, 1.5, 2.0])
                ChoiceChip(
                  label: Text('${rate}x'),
                  selected: (settings.ttsRate - rate).abs() < 0.01,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    settings.ttsRate = rate;
                    _tts.setRate(rate);
                  },
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                color: colors.text,
                tooltip: '上一章',
                onPressed: () => _tts.skipToChapter(_tts.chapterIndex - 1),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                iconSize: 30,
                icon: Icon(_tts.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () =>
                    _tts.isPlaying ? _tts.pause() : _tts.resume(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next),
                color: colors.text,
                tooltip: '下一章',
                onPressed: () => _tts.skipToChapter(_tts.chapterIndex + 1),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {
                  _tts.stop();
                  _saveProgress();
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('退出听书'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 目录 / 书签 / 想法 ----------

  void _showTocSheet() {
    final colors = context.read<ReaderSettings>().colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: colors.secondaryText,
                tabs: const [
                  Tab(text: '目录'),
                  Tab(text: '书签'),
                  Tab(text: '想法'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTocTab(sheetContext, colors),
                    _buildAnnotationTab(
                      sheetContext,
                      colors,
                      bookmarksOnly: true,
                    ),
                    _buildAnnotationTab(
                      sheetContext,
                      colors,
                      bookmarksOnly: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTocTab(BuildContext sheetContext, ReaderThemeColors colors) {
    return ListView.builder(
      itemCount: _chapters!.length,
      itemBuilder: (context, index) {
        final selected = index == _chapterIndex;
        return ListTile(
          title: Text(
            _chapters![index].title,
            style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : colors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: selected
              ? Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () {
            Navigator.of(sheetContext).pop();
            if (_tts.isActive) {
              _tts.skipToChapter(index);
            } else {
              _jumpToChapter(index);
            }
          },
        );
      },
    );
  }

  Widget _buildAnnotationTab(
    BuildContext sheetContext,
    ReaderThemeColors colors, {
    required bool bookmarksOnly,
  }) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final items = appState
            .annotationsOf(widget.book.id)
            .where((a) => bookmarksOnly
                ? a.type == AnnotationType.bookmark
                : a.type != AnnotationType.bookmark)
            .toList()
          ..sort((a, b) {
            final byChapter = a.chapterIndex.compareTo(b.chapterIndex);
            return byChapter != 0 ? byChapter : a.start.compareTo(b.start);
          });

        if (items.isEmpty) {
          return Center(
            child: Text(
              bookmarksOnly ? '暂无书签' : '暂无划线和想法\n长按正文文字即可划线',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondaryText, height: 1.6),
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final annotation = items[index];
            final chapterTitle = _chapters![annotation.chapterIndex].title;
            return ListTile(
              leading: Icon(
                switch (annotation.type) {
                  AnnotationType.bookmark => Icons.bookmark,
                  AnnotationType.highlight => Icons.border_color,
                  AnnotationType.note => Icons.chat_bubble_outline,
                },
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                annotation.selectedText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: colors.text),
              ),
              subtitle: Text(
                annotation.note == null
                    ? chapterTitle
                    : '$chapterTitle · 想法：${annotation.note}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.secondaryText),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: colors.secondaryText,
                onPressed: () => appState.removeAnnotation(annotation.id),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _jumpToChapter(
                  annotation.chapterIndex,
                  offset: annotation.start,
                );
              },
            );
          },
        );
      },
    );
  }
}
