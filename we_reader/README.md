# 微读（we_reader）

微信读书风格的 Flutter 阅读应用 MVP：看书 + 听书，本地 Mock 书城，iOS 优先的交互体验，全中文界面。

## 运行

```bash
flutter pub get
flutter run          # 连接 iOS 模拟器 / Android 设备均可
```

- Flutter 3.x / Dart 3，Material 3 + Cupertino 风格页面转场。
- 无需任何后端或密钥：书城内容、进度、笔记全部在本地。
- `flutter analyze` 无告警，`flutter test` 通过。

## 功能

| 模块 | 说明 |
| --- | --- |
| 发现 | 分类筛选、三个榜单（神作 / 飙升 / 新书）、搜索（书名 / 作者 / 分类）、书籍详情、加入书架 |
| 书架 | 网格封面 + 已读百分比，长按移出 / 查看详情，最近阅读自动置顶 |
| 阅读器 | TXT 与 EPUB（`epubx` 解析）、TextPainter 整行分页、左右翻页（PageView）与上下滚动两种模式、日间 / 夜间 / 护眼三主题、字号与行距调节、目录、全书进度条、页眉章节名 / 页脚进度 |
| 标注 | 长按选中正文 → 复制 / 划线 / 写想法；书签按页收藏；全部以「章节索引 + 字符偏移」定位，目录抽屉内可跳转与删除 |
| 听书 | `flutter_tts` 逐句朗读，**当前句实时高亮**并自动翻页跟随；语速 0.75x–2x；随时「退出听书」切回手动阅读；退出阅读器时未收藏会提示加入书架 |
| 我 | 总时长 / 今日时长 / 阅读天数 / 笔记数统计；云同步、会员等入口为占位 |

## 架构

```
lib/
├── main.dart                  # 入口：Provider 注入 + Material3 主题 + Cupertino 转场
├── models/models.dart         # Book / Chapter / Annotation / ReadingProgress
├── data/
│   ├── sample_books.dart      # 本地示例书库（6 本原创短文，5 本 TXT + 1 本 EPUB）
│   └── book_repository.dart   # 内容仓库：TXT 章节解析 + epubx 解析 EPUB，统一为 Chapter
├── providers/
│   ├── app_state.dart         # 书架 / 进度 / 标注 / 阅读统计，shared_preferences 持久化
│   └── reader_settings.dart   # 字号 / 行距 / 主题 / 翻页模式 / TTS 语速
├── reader/
│   ├── pagination.dart        # TextPainter 逐行排版分页（整行断页，偏移精确）
│   ├── sentence_splitter.dart # 中文标点分句（带章节内偏移）
│   ├── span_builder.dart      # 划线 / 想法 / TTS 当前句 → 着色 TextSpan
│   └── tts_controller.dart    # 逐句朗读调度、语速、跨章、暂停恢复
├── screens/                   # 发现 / 搜索 / 详情 / 书架 / 阅读器 / 我
└── widgets/book_cover.dart    # 程序化封面（渐变 + 书名）
```

设计要点：

- **定位统一用「章节索引 + 字符偏移」**：分页、滚动、划线、书签、TTS 高亮共享同一坐标系，换字号 / 换设备重新分页后标注不漂移。
- **分页**：用 `TextPainter.computeLineMetrics` 逐行累加高度、按整行断页，正文渲染与分页使用完全相同的文本与样式，保证所见即所得。
- **TTS 当前句高亮**：`TtsController` 分句后逐句 `speak`，每句开始时回调章节 + 句子区间，阅读器据此渲染高亮并自动翻页 / 滚动跟随。
- **示例书籍刻意精简**：每本 3-4 章、约 400-800 字的原创演示文本，重点在阅读器能力而非内容量。

## 云 TTS 接入点（Azure / 讯飞）

MVP 使用系统 TTS（iOS `AVSpeechSynthesizer` / Android TTS）。接入云端语音只需替换
`lib/reader/tts_controller.dart` 中的 `_speakSentence()`：

1. 把句子文本发给 Azure Speech（`tts.speech.microsoft.com` REST / SDK）或讯飞开放平台（WebSocket 流式合成），拿到音频流；
2. 用本地播放器（如 `just_audio`）播放，播放完成即返回；
3. 逐句调度、当前句高亮、语速、跨章逻辑全部复用；若云端返回字级时间戳，还可把高亮粒度从「句」细化到「字」。

无 TTS 引擎的环境（桌面 / 部分模拟器）会按字数模拟朗读时长，保证高亮与自动翻页仍可演示。

## 数据与未来同步

所有数据存 `shared_preferences`（JSON）：书架列表、每本书的进度、标注列表、按天阅读时长、阅读器设置。

进度与标注均带毫秒时间戳（`updatedAt` / `createdAt`）。未来接入账号体系后的同步策略：
登录时全量拉取服务端数据，与本地按条目对比，**最新时间戳获胜**（last-write-wins）双向合并；
之后进度节流上报、标注实时上报。

## MVP 边界（明确不做）

- 无 DRM、支付、会员，无真实后端与账号体系，社交 / 排行为占位；
- EPUB 仅解析文本（不渲染图片 / 样式）；
- 长按选中划线在「听书中」不可用（听书时正文为只读高亮态）；
- 长书需按章懒分页（当前示例书极短，全书一次分页）。

## 下一步

1. 真书城后端 + 分页拉取 / 缓存章节，长书懒分页；
2. 账号 + 云同步（策略见上）；
3. 云 TTS（Azure / 讯飞）+ 字级高亮 + 后台播放（`audio_service`）；
4. EPUB 富文本渲染（图片 / 样式）、更多字体与仿真翻页动画；
5. 阅读时长目标、周报、想法社区。
