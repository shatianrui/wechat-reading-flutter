# wechat-reading-flutter

微信读书风格的 Flutter 阅读应用「微读」（看书 + 听书）MVP。

Flutter 工程位于 [`we_reader/`](we_reader/)，运行方式、架构说明、MVP 边界与后续计划见 [`we_reader/README.md`](we_reader/README.md)。

## 快速开始

```bash
cd we_reader
flutter pub get
flutter run
```

## 功能一览

- 发现：分类筛选、榜单（神作 / 飙升 / 新书）、搜索、书籍详情、加入书架
- 书架：网格封面 + 阅读进度百分比，长按管理
- 阅读器：TXT + EPUB、整行分页、左右翻页 / 上下滚动、日间 / 夜间 / 护眼主题、字号与行距、目录、进度条、划线 / 想法 / 书签（章节 + 字符偏移定位）
- 听书：系统 TTS 逐句朗读、当前句高亮跟随、语速调节、读 / 听一键切换
- 我：本地阅读时长统计、笔记数量；书架 / 进度 / 标注 / 设置全部本地持久化
