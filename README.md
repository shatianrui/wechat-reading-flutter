# 微读 · we_reader

微信读书风格的 Flutter 阅读应用(看书 + 听书)MVP。**不含书城**:用户自行导入 EPUB / TXT 电子书,本地阅读、批注与 TTS 听书。iOS 优先的交互与视觉,Material 3 + Cupertino 细节。

## 功能一览

- **书架**:导入 EPUB / TXT(自动识别 GBK/UTF-8/UTF-16 编码、智能切分「第x章/回/节」),程序化封面、阅读进度百分比、长按移出书架;首次启动内置《微读使用指南》示例书。
- **阅读器**:
  - 自研分页引擎(TextPainter 逐行度量,分页与渲染同一套排版参数,断行严格一致);
  - 左右翻页 / 上下滚动两种模式;
  - 白纸 / 米黄 / 护眼绿 / 夜间四主题,字号、行距、衬线体可调;
  - 目录跳转、全书进度条、章节页码;
  - **批注**:长按选句 → 划线 / 写想法 / 复制;书签按页收藏;笔记面板可回看、跳转、删除。定位采用「章节索引 + 章内字符偏移」,对本地内容稳定。
- **听书(TTS)**:系统语音逐句朗读当前章节,支持语速调节、上一句/下一句;**听读联动**——正在朗读的句子实时高亮,翻页/滚动自动跟随,随时一键在读与听之间切换。
- **个人中心**:阅读统计(今日/累计/听书时长、藏书、笔记、读完数),账号与会员为占位(见「后续规划」)。
- **本地持久化**:书架、进度、批注、统计、阅读设置全部本地保存(shared_preferences + JSON)。

## 运行

```bash
flutter pub get
flutter run          # 连接 iOS 模拟器 / Android 设备
flutter test         # 单元 + 冒烟测试
flutter analyze      # 静态检查(当前零问题)
```

要求 Flutter 3.35+(开发环境为 3.47 stable)。iOS 与 Android 工程均已生成;竖屏锁定。

> 平台说明:TTS 依赖系统语音,iOS 模拟器与部分 Android 模拟器可能缺少中文语音包,真机体验最佳;桌面端(Linux/Windows)无 TTS 引擎时听书静默降级。iOS 已声明 `UIBackgroundModes: audio`,锁屏媒体控制(播放/暂停)需接入 `audio_service`,见后续规划。

## 架构

```
lib/
├── main.dart                  # 入口:Provider 装配 + MaterialApp
├── core/                      # 与 UI 无关的领域层
│   ├── models/                # Book / Chapter / Annotation / Progress / Stats
│   ├── content/               # EPUB 解析(epubx)、TXT 章节切分、编码探测(GBK)
│   ├── data/                  # BookRepository(导入/加载/缓存)、内置指南
│   ├── state/                 # LibraryController(书架/进度/批注/统计)、ReaderSettings
│   ├── storage/               # LocalStore(shared_preferences + JSON)
│   └── theme/                 # 全局 Material 3 主题
├── features/
│   ├── home/                  # 底部导航壳(书架 / 我)
│   ├── bookshelf/             # 书架 + 导入流程
│   ├── reader/                # 分页引擎、阅读页、TTS 控制器、设置/目录/笔记面板
│   └── profile/               # 个人中心
└── shared/widgets/            # 程序化书籍封面等通用组件
```

关键设计:

- **分页**:`Paginator` 用 `TextPainter.computeLineMetrics` 把章节文本切成 `[start, end)` 字符区间;页面渲染使用相同宽度与 TextStyle,保证一致。字号/行距/字体/窗口变化时以「章节 + 偏移」锚点重新分页并回到原位置。
- **批注定位**:`章节索引 + displayText 字符偏移`,EPUB 与 TXT 统一;将来接 EPUB CFI 可在 `Annotation` 上扩展 locator 字段而不破坏现有数据。
- **听读联动**:`TtsController` 按中文句读切分句子并保留区间,朗读回调驱动高亮与自动翻页;云 TTS(Azure / 讯飞)接入点即替换其 `_speak` 为云端合成音频播放,句子边界与高亮逻辑不变。
- **进度冲突策略**:`ReadingProgress.updatedAt` 最新时间戳优先(latest-wins),`LibraryController.updateProgress` 已按此实现,为将来云同步预留。

## MVP 边界(已知取舍)

- EPUB 提取为纯文本渲染(保证分页/批注/TTS 一致性),暂不渲染插图与富样式;
- 翻页模式为平移 + 滚动,未做仿真卷页动画;
- 长按选中以「句」为粒度,暂无拖拽手柄精调;
- 听书使用系统离线语音,无锁屏媒体控制;
- 账号、会员、云同步为 UI 占位;无 DRM、无内容分发。

## 后续规划

1. **云同步**:书架/进度/批注上云,按 `updatedAt` latest-wins 合并;
2. **云 TTS**:Azure Speech / 讯飞长文本合成,替换 `TtsController._speak`,加 `audio_service` 实现后台与锁屏控制;
3. **EPUB 富渲染**:内嵌封面、插图、CFI 定位;
4. **内容生态**:正版书城接入与 DRM(当前仅用户自有文件);
5. 仿真翻页动画、拖拽选区手柄、全文搜索。
