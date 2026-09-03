import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/data/book_repository.dart';
import '../../core/models/annotation.dart';
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/models/progress.dart';
import '../../core/state/library_controller.dart';
import '../../core/state/reader_settings.dart';
import 'pagination.dart';
import 'tts_controller.dart';
import 'widgets/listen_bar.dart';
import 'widgets/notes_sheet.dart';
import 'widgets/page_canvas.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/toc_sheet.dart';

/// 阅读器:分页/滚动阅读、主题字号、划线笔记书签、TTS 听读联动。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

/// 长按选中的文字范围。
class _Selection {
  const _Selection({
    required this.chapterIndex,
    required this.start,
    required this.end,
    required this.text,
  });

  final int chapterIndex;
  final int start;
  final int end;
  final String text;
}

class _ReaderPageState extends State<ReaderPage> {
  static const _hPad = 24.0;
  static const _headerH = 34.0;
  static const _footerH = 30.0;

  BookContent? _content;
  PaginatedBook? _paginated;
  String _pagKey = '';
  bool _paginating = false;

  PageController? _pageController;
  int _currentPage = 0;

  // 进度锚点:章节 + 章内偏移,跨分页/模式切换保持位置。
  int _anchorChapter = 0;
  int _anchorOffset = 0;

  bool _chrome = false;
  _Selection? _selection;
  TtsController? _tts;

  // 滚动模式状态。
  int _scrollChapter = 0;
  ScrollController? _scrollController;
  double _pendingScrollFraction = 0;

  final Stopwatch _session = Stopwatch()..start();
  bool _finishedRecorded = false;

  late final LibraryController _library;

  @override
  void initState() {
    super.initState();
    _library = context.read<LibraryController>();
    final progress = _library.progressFor(widget.book.id);
    _anchorChapter = progress?.chapterIndex ?? 0;
    _anchorOffset = progress?.charOffset ?? 0;
    _scrollChapter = _anchorChapter;
    _loadContent();
  }

  Future<void> _loadContent() async {
    final content = await BookRepository.instance.loadContent(widget.book);
    if (!mounted) return;
    setState(() {
      _content = content;
      _anchorChapter = _anchorChapter.clamp(0, content.chapters.length - 1);
      _scrollChapter = _anchorChapter;
    });
  }

  @override
  void dispose() {
    _persistOnExit();
    _tts?.dispose();
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _persistOnExit() {
    final listenSeconds = _tts?.listenSeconds ?? 0;
    final total = _session.elapsed.inSeconds;
    _library.recordTime(
      readSeconds: (total - listenSeconds).clamp(0, total),
      listenSeconds: listenSeconds,
    );
    _saveProgress();
  }

  // ---- 分页 ----

  double _firstPageReserved(ReaderSettingsController settings) =>
      (settings.fontSize + 7) * 1.4 + 26;

  void _ensurePaginated(Size bodySize, ReaderSettingsController settings) {
    final key =
        '${settings.fontSize}_${settings.lineHeight}_${settings.useSerif}_'
        '${bodySize.width.toStringAsFixed(1)}x${bodySize.height.toStringAsFixed(1)}';
    if (_pagKey == key || _paginating || _content == null) return;
    _paginating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final paginated = Paginator.paginate(
        chapters: _content!.chapters,
        bodyStyle: settings.bodyStyle(settings.theme),
        pageSize: bodySize,
        firstPageReserved: _firstPageReserved(settings),
      );
      final target = paginated.pageIndexFor(_anchorChapter, _anchorOffset);
      final old = _pageController;
      setState(() {
        _paginated = paginated;
        _pagKey = key;
        _paginating = false;
        _currentPage = target;
        _pageController = PageController(initialPage: target);
      });
      // 旧控制器等新 PageView 挂载后再释放,避免 detach 已释放的控制器。
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    });
  }

  // ---- 进度 ----

  void _updateAnchorFromPage(int pageIndex) {
    final paginated = _paginated;
    if (paginated == null || paginated.pages.isEmpty) return;
    final page = paginated.pages[pageIndex.clamp(0, paginated.pages.length - 1)];
    _anchorChapter = page.chapterIndex;
    _anchorOffset = page.start;
  }

  void _saveProgress() {
    final paginated = _paginated;
    final library = _library;
    double percent = 0;
    if (paginated != null && paginated.totalChars > 0) {
      final base = paginated.chapterCharBase[
          _anchorChapter.clamp(0, paginated.chapterCharBase.length - 1)];
      percent = ((base + _anchorOffset) / paginated.totalChars).clamp(0.0, 1.0);
      if (paginated.pages.isNotEmpty &&
          _currentPage >= paginated.pages.length - 1) {
        percent = 1;
      }
    }
    library.updateProgress(ReadingProgress(
      bookId: widget.book.id,
      chapterIndex: _anchorChapter,
      charOffset: _anchorOffset,
      percent: percent,
      updatedAt: DateTime.now(),
    ));
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _selection = null;
    });
    _updateAnchorFromPage(index);
    _saveProgress();
    final paginated = _paginated;
    if (!_finishedRecorded &&
        paginated != null &&
        paginated.pages.isNotEmpty &&
        index == paginated.pages.length - 1) {
      _finishedRecorded = true;
      context.read<LibraryController>().markFinished();
    }
  }

  // ---- 听书 ----

  Future<void> _toggleListen() async {
    final paginated = _paginated;
    if (paginated == null) return;
    var tts = _tts;
    if (tts != null && tts.active) {
      await tts.stop();
      setState(() {});
      return;
    }
    final settings = context.read<ReaderSettingsController>();
    if (tts == null) {
      tts = TtsController(rate: settings.ttsRate);
      tts.addListener(_onTtsChanged);
      _tts = tts;
    }
    setState(() => _chrome = false);
    await tts.start(
      book: paginated,
      chapterIndex: _anchorChapter,
      charOffset: _anchorOffset,
    );
  }

  void _onTtsChanged() {
    if (!mounted) return;
    final tts = _tts;
    final paginated = _paginated;
    setState(() {});
    final sentence = tts?.currentSentence;
    if (tts == null || sentence == null || paginated == null) return;

    final settings = context.read<ReaderSettingsController>();
    if (settings.pageMode == PageTurnMode.slide) {
      final target = paginated.pageIndexFor(sentence.chapterIndex, sentence.start);
      if (target != _currentPage && _pageController != null) {
        _pageController!.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    } else {
      if (sentence.chapterIndex != _scrollChapter) {
        setState(() {
          _scrollChapter = sentence.chapterIndex;
          _pendingScrollFraction = 0;
        });
      } else {
        final controller = _scrollController;
        final text = paginated.chapterTexts[sentence.chapterIndex];
        if (controller != null && controller.hasClients && text.isNotEmpty) {
          final fraction = sentence.start / text.length;
          final target = (controller.position.maxScrollExtent * fraction -
                  120)
              .clamp(0.0, controller.position.maxScrollExtent);
          controller.animateTo(target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      }
      _anchorChapter = sentence.chapterIndex;
      _anchorOffset = sentence.start;
    }
  }

  // ---- 划线/笔记/书签 ----

  static const _sentenceBreakers = '。!?;!?;…\n';

  void _selectSentenceAt(int chapterIndex, int charOffset) {
    final paginated = _paginated;
    if (paginated == null) return;
    final text = paginated.chapterTexts[chapterIndex];
    if (text.isEmpty) return;
    final pos = charOffset.clamp(0, text.length - 1);
    var start = pos;
    while (start > 0 && !_sentenceBreakers.contains(text[start - 1])) {
      start--;
    }
    var end = pos;
    while (end < text.length && !_sentenceBreakers.contains(text[end])) {
      end++;
    }
    if (end < text.length) end++; // 含句末标点。
    final selectedText =
        text.substring(start, end).replaceAll('\u3000', '').trim();
    if (selectedText.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selection = _Selection(
        chapterIndex: chapterIndex,
        start: start,
        end: end,
        text: selectedText,
      );
      _chrome = false;
    });
  }

  Future<void> _addHighlight({String note = ''}) async {
    final selection = _selection;
    if (selection == null) return;
    final library = context.read<LibraryController>();
    await library.addAnnotation(Annotation(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      bookId: widget.book.id,
      type: note.isEmpty ? AnnotationType.highlight : AnnotationType.note,
      chapterIndex: selection.chapterIndex,
      start: selection.start,
      end: selection.end,
      text: selection.text,
      noteContent: note,
      createdAt: DateTime.now(),
    ));
    if (mounted) setState(() => _selection = null);
  }

  Future<void> _writeNote() async {
    final selection = _selection;
    if (selection == null) return;
    final theme = context.read<ReaderSettingsController>().theme;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('写想法',
            style: TextStyle(fontSize: 16, color: theme.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selection.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: theme.text),
              decoration: InputDecoration(
                hintText: '写下这一刻的想法…',
                hintStyle:
                    TextStyle(fontSize: 13, color: theme.secondaryText),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (note != null && note.isNotEmpty) {
      await _addHighlight(note: note);
    }
  }

  Future<void> _toggleBookmark() async {
    final paginated = _paginated;
    if (paginated == null || paginated.pages.isEmpty) return;
    final library = context.read<LibraryController>();
    final page = paginated.pages[_currentPage];
    final existing = library.annotationsFor(widget.book.id).where((a) =>
        a.type == AnnotationType.bookmark &&
        a.chapterIndex == page.chapterIndex &&
        a.start >= page.start &&
        a.start < page.end);
    if (existing.isNotEmpty) {
      for (final a in existing) {
        await library.removeAnnotation(a.id);
      }
      return;
    }
    final text = paginated.chapterTexts[page.chapterIndex];
    final preview = text
        .substring(page.start, (page.start + 40).clamp(0, text.length))
        .replaceAll('\u3000', '')
        .replaceAll('\n', ' ')
        .trim();
    await library.addAnnotation(Annotation(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      bookId: widget.book.id,
      type: AnnotationType.bookmark,
      chapterIndex: page.chapterIndex,
      start: page.start,
      end: page.start,
      text: preview,
      createdAt: DateTime.now(),
    ));
  }

  // ---- 导航 ----

  void _jumpToPage(int index) {
    final paginated = _paginated;
    if (paginated == null || paginated.pages.isEmpty) return;
    final target = index.clamp(0, paginated.pages.length - 1);
    _pageController?.jumpToPage(target);
    _onPageChanged(target);
  }

  void _jumpToChapter(int chapterIndex) {
    final paginated = _paginated;
    if (paginated == null) return;
    _anchorChapter = chapterIndex;
    _anchorOffset = 0;
    final settings = context.read<ReaderSettingsController>();
    if (settings.pageMode == PageTurnMode.slide) {
      _jumpToPage(paginated.chapterFirstPage[chapterIndex]);
    } else {
      setState(() {
        _scrollChapter = chapterIndex;
        _pendingScrollFraction = 0;
        _selection = null;
      });
      _saveProgress();
    }
  }

  void _jumpToAnnotation(Annotation annotation) {
    final paginated = _paginated;
    if (paginated == null) return;
    _anchorChapter = annotation.chapterIndex;
    _anchorOffset = annotation.start;
    final settings = context.read<ReaderSettingsController>();
    if (settings.pageMode == PageTurnMode.slide) {
      _jumpToPage(
          paginated.pageIndexFor(annotation.chapterIndex, annotation.start));
    } else {
      final text = paginated.chapterTexts[annotation.chapterIndex];
      setState(() {
        _scrollChapter = annotation.chapterIndex;
        _pendingScrollFraction =
            text.isEmpty ? 0 : annotation.start / text.length;
        _selection = null;
      });
      _saveProgress();
    }
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ReaderSettingsController>();
    final theme = settings.theme;
    final library = context.watch<LibraryController>();

    return Scaffold(
      backgroundColor: theme.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: _content == null
            ? Center(
                child: CupertinoActivityIndicator(color: theme.secondaryText))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final media = MediaQuery.of(context);
                  final bodySize = Size(
                    constraints.maxWidth - _hPad * 2,
                    constraints.maxHeight -
                        media.padding.top -
                        media.padding.bottom -
                        _headerH -
                        _footerH,
                  );
                  _ensurePaginated(bodySize, settings);
                  final paginated = _paginated;
                  if (paginated == null) {
                    return Center(
                        child: CupertinoActivityIndicator(
                            color: theme.secondaryText));
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: settings.pageMode == PageTurnMode.slide
                            ? _buildSlideReader(
                                paginated, settings, theme, library, bodySize)
                            : _buildScrollReader(
                                paginated, settings, theme, library, bodySize),
                      ),
                      if (_selection != null)
                        _buildSelectionToolbar(theme),
                      _buildChrome(paginated, settings, theme, library),
                      if (_tts?.active ?? false)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: media.padding.bottom + 8,
                          child: ListenBar(
                            tts: _tts!,
                            theme: theme,
                            onRateChanged: (v) {
                              settings.ttsRate = v;
                              _tts!.setRate(v);
                            },
                            onExit: () async {
                              await _tts!.stop();
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // ---- 左右翻页模式 ----

  Widget _buildSlideReader(
    PaginatedBook paginated,
    ReaderSettingsController settings,
    ReaderTheme theme,
    LibraryController library,
    Size bodySize,
  ) {
    final annotations = library.annotationsFor(widget.book.id);
    final ttsSentence = _tts?.active == true ? _tts?.currentSentence : null;

    return PageView.builder(
      key: ValueKey('pv_$_pagKey'),
      controller: _pageController,
      itemCount: paginated.pages.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final page = paginated.pages[index];
        final text = paginated.chapterTexts[page.chapterIndex]
            .substring(page.start, page.end);
        final ranges = [
          ...annotationRanges(
            annotations: annotations,
            chapterIndex: page.chapterIndex,
            theme: theme,
          ),
          if (ttsSentence != null &&
              ttsSentence.chapterIndex == page.chapterIndex)
            HighlightRange(
              start: ttsSentence.start,
              end: ttsSentence.end,
              color: theme.ttsHighlight,
            ),
          if (_selection != null &&
              _selection!.chapterIndex == page.chapterIndex)
            HighlightRange(
              start: _selection!.start,
              end: _selection!.end,
              color: theme.highlight,
            ),
        ];
        return _ReaderPageCanvas(
          page: page,
          pageText: text,
          chapterTitle: paginated.chapterTitles[page.chapterIndex],
          bookTitle: widget.book.title,
          settings: settings,
          theme: theme,
          bodySize: bodySize,
          firstPageReserved: _firstPageReserved(settings),
          ranges: ranges,
          footer:
              '${(paginated.percentAt(index) * 100).toStringAsFixed(1)}%  ·  '
              '${page.pageInChapter + 1}/${_chapterPageCount(paginated, page.chapterIndex)}',
          hasBookmark: library.hasBookmark(
              widget.book.id, page.chapterIndex, page.start, page.end),
          onTapZone: (zone) => _handleTapZone(zone, paginated),
          onLongPressAt: (offset) =>
              _selectSentenceAt(page.chapterIndex, page.start + offset),
        );
      },
    );
  }

  int _chapterPageCount(PaginatedBook paginated, int chapterIndex) {
    final first = paginated.chapterFirstPage[chapterIndex];
    var count = 0;
    for (var i = first;
        i < paginated.pages.length &&
            paginated.pages[i].chapterIndex == chapterIndex;
        i++) {
      count++;
    }
    return count;
  }

  void _handleTapZone(_TapZone zone, PaginatedBook paginated) {
    if (_selection != null) {
      setState(() => _selection = null);
      return;
    }
    switch (zone) {
      case _TapZone.left:
        if (_chrome) {
          setState(() => _chrome = false);
        } else {
          _jumpToPageAnimated(_currentPage - 1);
        }
      case _TapZone.center:
        setState(() => _chrome = !_chrome);
      case _TapZone.right:
        if (_chrome) {
          setState(() => _chrome = false);
        } else {
          _jumpToPageAnimated(_currentPage + 1);
        }
    }
  }

  void _jumpToPageAnimated(int index) {
    final paginated = _paginated;
    if (paginated == null) return;
    if (index < 0 || index >= paginated.pages.length) return;
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  // ---- 上下滚动模式 ----

  Widget _buildScrollReader(
    PaginatedBook paginated,
    ReaderSettingsController settings,
    ReaderTheme theme,
    LibraryController library,
    Size bodySize,
  ) {
    final chapterIndex =
        _scrollChapter.clamp(0, paginated.chapterTexts.length - 1);
    final text = paginated.chapterTexts[chapterIndex];
    final annotations = library.annotationsFor(widget.book.id);
    final ttsSentence = _tts?.active == true ? _tts?.currentSentence : null;

    final ranges = [
      ...annotationRanges(
        annotations: annotations,
        chapterIndex: chapterIndex,
        theme: theme,
      ),
      if (ttsSentence != null && ttsSentence.chapterIndex == chapterIndex)
        HighlightRange(
          start: ttsSentence.start,
          end: ttsSentence.end,
          color: theme.ttsHighlight,
        ),
      if (_selection != null && _selection!.chapterIndex == chapterIndex)
        HighlightRange(
          start: _selection!.start,
          end: _selection!.end,
          color: theme.highlight,
        ),
    ];

    return _ScrollChapterReader(
      key: ValueKey('scroll_${chapterIndex}_$_pagKey'),
      chapterIndex: chapterIndex,
      chapterTitle: paginated.chapterTitles[chapterIndex],
      text: text,
      settings: settings,
      theme: theme,
      ranges: ranges,
      hPad: _hPad,
      hasPrev: chapterIndex > 0,
      hasNext: chapterIndex < paginated.chapterTexts.length - 1,
      initialFraction: _pendingScrollFraction,
      onControllerReady: (controller) => _scrollController = controller,
      onTap: () {
        if (_selection != null) {
          setState(() => _selection = null);
        } else {
          setState(() => _chrome = !_chrome);
        }
      },
      onLongPressAt: (offset) => _selectSentenceAt(chapterIndex, offset),
      onProgress: (charOffset) {
        _anchorChapter = chapterIndex;
        _anchorOffset = charOffset.clamp(0, text.isEmpty ? 0 : text.length - 1);
        _saveProgress();
      },
      onSwitchChapter: (delta) {
        final next = chapterIndex + delta;
        if (next < 0 || next >= paginated.chapterTexts.length) return;
        _jumpToChapter(next);
      },
    );
  }

  // ---- 划线工具条 ----

  Widget _buildSelectionToolbar(ReaderTheme theme) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(context).padding.bottom + 90,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.isDark ? const Color(0xFF2C2D31) : const Color(0xFF3A3B40),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolbarAction(
              icon: CupertinoIcons.underline,
              label: '划线',
              onTap: _addHighlight,
            ),
            _ToolbarAction(
              icon: CupertinoIcons.text_bubble,
              label: '想法',
              onTap: _writeNote,
            ),
            _ToolbarAction(
              icon: CupertinoIcons.doc_on_doc,
              label: '复制',
              onTap: () async {
                await Clipboard.setData(
                    ClipboardData(text: _selection?.text ?? ''));
                if (mounted) setState(() => _selection = null);
              },
            ),
            _ToolbarAction(
              icon: CupertinoIcons.xmark,
              label: '取消',
              onTap: () => setState(() => _selection = null),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 工具栏(顶部 + 底部) ----

  Widget _buildChrome(
    PaginatedBook paginated,
    ReaderSettingsController settings,
    ReaderTheme theme,
    LibraryController library,
  ) {
    final media = MediaQuery.of(context);
    final page = paginated.pages.isEmpty
        ? null
        : paginated.pages[_currentPage.clamp(0, paginated.pages.length - 1)];
    final chapterIndex = settings.pageMode == PageTurnMode.slide
        ? (page?.chapterIndex ?? 0)
        : _scrollChapter;
    final bookmarked = page != null &&
        library.hasBookmark(
            widget.book.id, page.chapterIndex, page.start, page.end);

    return Stack(
      children: [
        // 顶部栏。
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          top: _chrome ? 0 : -(media.padding.top + 56),
          child: Container(
            padding: EdgeInsets.only(top: media.padding.top),
            color: theme.surface,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.chevron_back,
                        color: theme.text, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.text),
                    ),
                  ),
                  if (settings.pageMode == PageTurnMode.slide)
                    IconButton(
                      icon: Icon(
                        bookmarked
                            ? CupertinoIcons.bookmark_fill
                            : CupertinoIcons.bookmark,
                        color: bookmarked
                            ? const Color(0xFFE0A030)
                            : theme.text,
                        size: 20,
                      ),
                      tooltip: '书签',
                      onPressed: _toggleBookmark,
                    ),
                  IconButton(
                    icon: Icon(CupertinoIcons.square_list,
                        color: theme.text, size: 21),
                    tooltip: '笔记',
                    onPressed: () async {
                      final annotation = await showNotesSheet(
                        context: context,
                        bookId: widget.book.id,
                        book: paginated,
                        theme: theme,
                      );
                      if (annotation != null) _jumpToAnnotation(annotation);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // 底部栏。
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: _chrome ? 0 : -(media.padding.bottom + 150),
          child: Container(
            padding: EdgeInsets.only(bottom: media.padding.bottom + 6),
            color: theme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings.pageMode == PageTurnMode.slide &&
                    paginated.pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Text('${((_currentPage + 1) / paginated.pages.length * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 11, color: theme.secondaryText)),
                        Expanded(
                          child: Slider(
                            value: _currentPage
                                .toDouble()
                                .clamp(0, (paginated.pages.length - 1).toDouble()),
                            max: (paginated.pages.length - 1).toDouble(),
                            activeColor: const Color(0xFF4C8AF0),
                            inactiveColor:
                                theme.secondaryText.withValues(alpha: 0.2),
                            onChanged: (v) => _jumpToPage(v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            paginated.chapterTitles[chapterIndex],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11, color: theme.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ChromeButton(
                      icon: CupertinoIcons.list_bullet,
                      label: '目录',
                      theme: theme,
                      onTap: () async {
                        final target = await showTocSheet(
                          context: context,
                          book: paginated,
                          currentChapter: chapterIndex,
                          theme: theme,
                          bookTitle: widget.book.title,
                        );
                        if (target != null) _jumpToChapter(target);
                      },
                    ),
                    _ChromeButton(
                      icon: _tts?.active == true
                          ? CupertinoIcons.headphones
                          : CupertinoIcons.headphones,
                      label: _tts?.active == true ? '停止听书' : '听书',
                      theme: theme,
                      active: _tts?.active == true,
                      onTap: _toggleListen,
                    ),
                    _ChromeButton(
                      icon: theme.isDark
                          ? CupertinoIcons.sun_max
                          : CupertinoIcons.moon,
                      label: theme.isDark ? '日间' : '夜间',
                      theme: theme,
                      onTap: () => settings.themeKind = theme.isDark
                          ? ReaderThemeKind.paper
                          : ReaderThemeKind.night,
                    ),
                    _ChromeButton(
                      icon: CupertinoIcons.textformat_size,
                      label: '设置',
                      theme: theme,
                      onTap: () => showReaderSettingsSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _TapZone { left, center, right }

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final ReaderTheme theme;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF4C8AF0) : theme.text;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

/// 单页画布:头部章节名、正文、底部进度,处理点按分区与长按选句。
class _ReaderPageCanvas extends StatelessWidget {
  const _ReaderPageCanvas({
    required this.page,
    required this.pageText,
    required this.chapterTitle,
    required this.bookTitle,
    required this.settings,
    required this.theme,
    required this.bodySize,
    required this.firstPageReserved,
    required this.ranges,
    required this.footer,
    required this.hasBookmark,
    required this.onTapZone,
    required this.onLongPressAt,
  });

  final PageSlice page;
  final String pageText;
  final String chapterTitle;
  final String bookTitle;
  final ReaderSettingsController settings;
  final ReaderTheme theme;
  final Size bodySize;
  final double firstPageReserved;
  final List<HighlightRange> ranges;
  final String footer;
  final bool hasBookmark;
  final ValueChanged<_TapZone> onTapZone;

  /// 回调参数:页内字符偏移。
  final ValueChanged<int> onLongPressAt;

  void _handleLongPress(Offset local) {
    var dy = local.dy;
    if (page.isChapterFirst) dy -= firstPageReserved;
    if (dy < 0) dy = 0;
    final painter = TextPainter(
      text: TextSpan(text: pageText, style: settings.bodyStyle(theme)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: bodySize.width);
    final offset =
        painter.getPositionForOffset(Offset(local.dx, dy)).offset;
    painter.dispose();
    onLongPressAt(offset.clamp(0, pageText.isEmpty ? 0 : pageText.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bodyStyle = settings.bodyStyle(theme);
    final segmentRanges = ranges
        .map((r) => HighlightRange(
              start: r.start - page.start,
              end: r.end - page.start,
              color: r.color,
              underline: r.underline,
            ))
        .toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final w = media.size.width;
        final x = details.globalPosition.dx;
        if (x < w * 0.3) {
          onTapZone(_TapZone.left);
        } else if (x > w * 0.7) {
          onTapZone(_TapZone.right);
        } else {
          onTapZone(_TapZone.center);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: _ReaderPageState._hPad,
          right: _ReaderPageState._hPad,
          top: media.padding.top,
          bottom: media.padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页眉。
            SizedBox(
              height: _ReaderPageState._headerH,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        page.isChapterFirst ? bookTitle : chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: theme.secondaryText),
                      ),
                    ),
                  ),
                  if (hasBookmark)
                    Icon(CupertinoIcons.bookmark_fill,
                        size: 13, color: const Color(0xFFE0A030)),
                ],
              ),
            ),
            // 正文区(尺寸与分页引擎一致)。
            SizedBox(
              width: bodySize.width,
              height: bodySize.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (details) =>
                    _handleLongPress(details.localPosition),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (page.isChapterFirst)
                      SizedBox(
                        height: firstPageReserved,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              chapterTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: settings.fontSize + 7,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                                color: theme.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: buildHighlightedSpans(
                            text: pageText,
                            segmentStart: 0,
                            style: bodyStyle,
                            ranges: segmentRanges,
                          ),
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 页脚。
            SizedBox(
              height: _ReaderPageState._footerH,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  footer,
                  style: TextStyle(fontSize: 11, color: theme.secondaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 上下滚动模式:整章连续滚动 + 章节切换。
class _ScrollChapterReader extends StatefulWidget {
  const _ScrollChapterReader({
    super.key,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.text,
    required this.settings,
    required this.theme,
    required this.ranges,
    required this.hPad,
    required this.hasPrev,
    required this.hasNext,
    required this.initialFraction,
    required this.onControllerReady,
    required this.onTap,
    required this.onLongPressAt,
    required this.onProgress,
    required this.onSwitchChapter,
  });

  final int chapterIndex;
  final String chapterTitle;
  final String text;
  final ReaderSettingsController settings;
  final ReaderTheme theme;
  final List<HighlightRange> ranges;
  final double hPad;
  final bool hasPrev;
  final bool hasNext;
  final double initialFraction;
  final ValueChanged<ScrollController> onControllerReady;
  final VoidCallback onTap;
  final ValueChanged<int> onLongPressAt;
  final ValueChanged<int> onProgress;
  final ValueChanged<int> onSwitchChapter;

  @override
  State<_ScrollChapterReader> createState() => _ScrollChapterReaderState();
}

class _ScrollChapterReaderState extends State<_ScrollChapterReader> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.onControllerReady(_controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (widget.initialFraction > 0) {
        _controller
            .jumpTo(_controller.position.maxScrollExtent * widget.initialFraction);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleLongPress(Offset localInText, double textWidth) {
    final painter = TextPainter(
      text: TextSpan(
          text: widget.text,
          style: widget.settings.bodyStyle(widget.theme)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);
    final offset = painter.getPositionForOffset(localInText).offset;
    painter.dispose();
    widget.onLongPressAt(
        offset.clamp(0, widget.text.isEmpty ? 0 : widget.text.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bodyStyle = widget.settings.bodyStyle(widget.theme);
    final textWidth = media.size.width - widget.hPad * 2;

    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        final position = _controller.position;
        if (position.maxScrollExtent > 0 && widget.text.isNotEmpty) {
          final fraction =
              (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
          widget.onProgress((fraction * widget.text.length).round());
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SingleChildScrollView(
          controller: _controller,
          padding: EdgeInsets.only(
            left: widget.hPad,
            right: widget.hPad,
            top: media.padding.top + 40,
            bottom: media.padding.bottom + 60,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.hasPrev)
                Center(
                  child: TextButton(
                    onPressed: () => widget.onSwitchChapter(-1),
                    child: Text('上一章',
                        style: TextStyle(
                            fontSize: 13, color: widget.theme.secondaryText)),
                  ),
                ),
              Text(
                widget.chapterTitle,
                style: TextStyle(
                  fontSize: widget.settings.fontSize + 7,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.text,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (details) =>
                    _handleLongPress(details.localPosition, textWidth),
                child: Text.rich(
                  TextSpan(
                    children: buildHighlightedSpans(
                      text: widget.text,
                      segmentStart: 0,
                      style: bodyStyle,
                      ranges: widget.ranges,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: widget.hasNext
                    ? TextButton(
                        onPressed: () => widget.onSwitchChapter(1),
                        child: Text('下一章',
                            style: TextStyle(
                                fontSize: 13,
                                color: widget.theme.secondaryText)),
                      )
                    : Text('— 全书完 —',
                        style: TextStyle(
                            fontSize: 13, color: widget.theme.secondaryText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
