import '../models/book.dart';
import '../models/chapter.dart';

/// 内置《使用指南》:让应用首次启动即有可读内容,
/// 同时演示阅读器与听书功能。不属于书城,仅作引导。
abstract final class BuiltinGuide {
  static const bookId = 'builtin-guide';

  static Book get book => Book(
        id: bookId,
        title: '微读使用指南',
        author: '微读团队',
        fileName: '',
        contentType: BookContentType.txt,
        importedAt: DateTime.fromMillisecondsSinceEpoch(0),
        wordCount: 900,
        coverSeed: 7,
      );

  static List<Chapter> get chapters => const [
        Chapter(
          title: '欢迎使用微读',
          paragraphs: [
            '欢迎来到微读,一款专注阅读体验的看书与听书应用。',
            '你的书架完全由自己做主:点击书架右上角的加号,即可从手机中导入 EPUB 或 TXT 格式的电子书。导入的书籍会保存在应用内,随时离线阅读。',
            '本指南同时也是一本示例书,你可以用它体验翻页、换主题、划线笔记和听书朗读等全部功能。',
          ],
        ),
        Chapter(
          title: '导入你的第一本书',
          paragraphs: [
            '在书架页点击右上角的加号,选择手机中的 EPUB 或 TXT 文件即可导入。',
            'EPUB 会自动读取书名、作者与目录;TXT 会智能识别「第一章」「第二回」等常见章节标题,并自动处理 GBK 等中文编码,乱码不再来。',
            '长按书架上的书籍,可以将它从书架移除。',
          ],
        ),
        Chapter(
          title: '打磨过的阅读体验',
          paragraphs: [
            '点击页面中央呼出工具栏:可调节字号、行距,切换白纸、米黄、护眼绿与夜间四种主题,并支持左右翻页与上下滚动两种模式。',
            '长按选中文字,即可划线标记或写下想法;点击工具栏中的书签图标,可以为当前页面添加书签。所有笔记都保存在本地,可随时回看。',
            '底部进度条支持快速跳转,目录面板可直达任意章节。阅读进度会自动记录,下次打开直接回到上次的位置。',
          ],
        ),
        Chapter(
          title: '边听边读',
          paragraphs: [
            '点击工具栏中的耳机图标,即可切换到听书模式,应用会用系统语音朗读当前章节。',
            '朗读时,正在播放的句子会以高亮标出,并自动翻页跟随,让眼睛与耳朵保持同步;你也可以随时暂停,回到安静的阅读。',
            '支持调节朗读语速。当前版本使用系统离线语音,后续版本可接入云端高品质音色。',
          ],
        ),
        Chapter(
          title: '关于数据与同步',
          paragraphs: [
            '书架、进度、笔记与统计全部保存在本机,不需要注册账号。',
            '云同步在规划中:届时将以「最新时间戳优先」策略合并多端进度,先读到后面的设备说了算。',
            '祝你阅读愉快。',
          ],
        ),
      ];
}
