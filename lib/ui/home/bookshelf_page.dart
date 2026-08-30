/// 书架页：书籍网格展示、TXT 导入、编辑模式（拖拽排序 / 批量删除 / 移动分组）、分组筛选。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/model/models.dart';
import '../../logic/import_service.dart';
import '../../logic/providers.dart';
import '../reader/reader_page.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  bool _importing = false;

  // 编辑模式状态
  bool _editing = false;
  final Set<int> _selectedIds = {};

  // 当前筛选的分组 id，null = 全部
  int? _filterGroupId;

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final service = ImportService(ref.read(bookRepositoryProvider));
      final result = await service.pickAndImport();
      if (!mounted) return;
      if (result.success || result.message.isNotEmpty) {
        ref.invalidate(bookListProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<BookWithProgress> visible) {
    setState(() {
      if (_selectedIds.length >= visible.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(visible.map((b) => b.book.id));
      }
    });
  }

  void _openReader(BookWithProgress item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderPage(book: item.book),
    )).then((_) => ref.invalidate(bookListProvider));
  }

  // ---- 编辑模式操作 ----

  /// 拖拽落位：把 [draggedId] 移动到全书列表中 [targetId] 的位置并持久化。
  Future<void> _reorder(int draggedId, int targetId) async {
    if (draggedId == targetId) return;
    final books = ref.read(bookListProvider).value;
    if (books == null) return;
    final ids = books.map((b) => b.book.id).toList();
    ids.remove(draggedId);
    final targetIndex = ids.indexOf(targetId);
    if (targetIndex < 0) return;
    ids.insert(targetIndex, draggedId);
    await ref.read(bookRepositoryProvider).reorderBooks(ids);
    ref.invalidate(bookListProvider);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定从书架移除选中的 ${_selectedIds.length} 本书吗？\n（不会删除磁盘上的 TXT 文件）'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(bookRepositoryProvider);
    for (final id in _selectedIds) {
      await repo.deleteBook(id);
    }
    setState(_selectedIds.clear);
    ref.invalidate(bookListProvider);
  }

  Future<void> _moveSelectedToGroup() async {
    if (_selectedIds.isEmpty) return;
    final groups = ref.read(bookGroupsProvider).value ?? const <BookGroup>[];
    // id == -1 表示「移出分组」；null 表示弹层被直接关闭，不做事
    const removeFromGroup = BookGroup(id: -1, name: '');
    final target = await showModalBottomSheet<BookGroup>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('移动至分组', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('移出分组'),
              onTap: () => Navigator.pop(ctx, removeFromGroup),
            ),
            for (final g in groups)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(g.name),
                onTap: () => Navigator.pop(ctx, g),
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建分组'),
              onTap: () async {
                final name = await _promptGroupName(ctx);
                if (name == null || name.isEmpty) return;
                final id = await ref.read(bookRepositoryProvider).createGroup(name);
                if (!ctx.mounted) return;
                Navigator.pop(
                    ctx, BookGroup(id: id, name: name));
              },
            ),
          ],
        ),
      ),
    );
    if (target == null) return;
    final repo = ref.read(bookRepositoryProvider);
    for (final id in _selectedIds) {
      await repo.setBookGroup(id, target.id == -1 ? null : target.id);
    }
    ref
      ..invalidate(bookListProvider)
      ..invalidate(bookGroupsProvider);
  }

  // ---- 分组管理 ----

  Future<String?> _promptGroupName(BuildContext ctx, {String? initial}) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? '新建分组' : '重命名分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '分组名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = await _promptGroupName(context);
    if (name == null || name.isEmpty) return;
    final id = await ref.read(bookRepositoryProvider).createGroup(name);
    setState(() => _filterGroupId = id);
    ref.invalidate(bookGroupsProvider);
  }

  Future<void> _manageGroup(BookGroup group) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除分组'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') {
      if (!mounted) return;
      final name = await _promptGroupName(context, initial: group.name);
      if (name == null || name.isEmpty) return;
      await ref.read(bookRepositoryProvider).renameGroup(group.id, name);
      ref.invalidate(bookGroupsProvider);
    } else if (action == 'delete') {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('删除分组「${group.name}」'),
          content: const Text('分组内的书籍将回到「全部」，不会被删除。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除')),
          ],
        ),
      );
      if (confirmed != true) return;
      if (_filterGroupId == group.id) setState(() => _filterGroupId = null);
      await ref.read(bookRepositoryProvider).deleteGroup(group.id);
      ref
        ..invalidate(bookListProvider)
        ..invalidate(bookGroupsProvider);
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookListProvider);
    final groupsAsync = ref.watch(bookGroupsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _editing ? _buildEditAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          _buildGroupBar(groupsAsync.value ?? const []),
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (books) {
                final visible = _filterGroupId == null
                    ? books
                    : books
                        .where((b) => b.book.groupId == _filterGroupId)
                        .toList();
                if (books.isEmpty) return _buildEmpty();
                if (visible.isEmpty) {
                  return const Center(child: Text('该分组还没有书籍'));
                }
                return _editing
                    ? _buildEditGrid(visible)
                    : _buildGrid(visible);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _editing ? _buildEditBottomBar() : null,
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    final appNameStyle = Theme.of(context).textTheme.titleLarge;
    return AppBar(
      backgroundColor: Colors.transparent,
      title: Text(appName, style: appNameStyle),
      actions: [
        IconButton(
          tooltip: '编辑',
          onPressed: () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: '导入 TXT',
          onPressed: _importing ? null : _import,
          icon: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.file_upload_outlined),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildEditAppBar() {
    final style = Theme.of(context).textTheme.titleLarge;
    return AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        tooltip: '全选',
        onPressed: () {
          final books = ref.read(bookListProvider).value ?? const [];
          final visible = _filterGroupId == null
              ? books
              : books.where((b) => b.book.groupId == _filterGroupId).toList();
          _toggleSelectAll(visible);
        },
        icon: const Icon(Icons.select_all),
      ),
      title: Text('已选 ${_selectedIds.length}', style: style),
      actions: [
        TextButton(
          onPressed: _toggleEditing,
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _buildGroupBar(List<BookGroup> groups) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _filterGroupId == null,
            onSelected: (_) => setState(() => _filterGroupId = null),
          ),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onLongPress: () => _manageGroup(g),
                child: ChoiceChip(
                  label: Text(g.name),
                  selected: _filterGroupId == g.id,
                  onSelected: (_) =>
                      setState(() => _filterGroupId = g.id),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('新建'),
              onPressed: _createGroup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('书架空空如也'),
          const SizedBox(height: 4),
          Text('点击右上角按钮导入本地 TXT 小说',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildGrid(List<BookWithProgress> visible) {
    return GridView.builder(
      // 底部留白：主框架 extendBody 后内容会延伸到透明导航栏后面
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: visible.length,
      itemBuilder: (ctx, i) {
        final item = visible[i];
        return _BookCard(
          item: item,
          onTap: () => _openReader(item),
        );
      },
    );
  }

  /// 编辑模式网格：点击勾选，长按拖拽排序。
  Widget _buildEditGrid(List<BookWithProgress> visible) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: visible.length,
      itemBuilder: (ctx, i) {
        final item = visible[i];
        return LongPressDraggable<BookWithProgress>(
          data: item,
          maxSimultaneousDrags: 1,
          feedback: _DragFeedbackCard(title: item.book.title),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _editCard(item),
          ),
          child: DragTarget<BookWithProgress>(
            onWillAcceptWithDetails: (d) => d.data.book.id != item.book.id,
            onAcceptWithDetails: (d) =>
                _reorder(d.data.book.id, item.book.id),
            builder: (ctx, candidate, _) => _editCard(item,
                highlighted: candidate.isNotEmpty),
          ),
        );
      },
    );
  }

  Widget _editCard(BookWithProgress item, {bool highlighted = false}) {
    final selected = _selectedIds.contains(item.book.id);
    return _BookCard(
      item: item,
      onTap: () {
        setState(() {
          if (selected) {
            _selectedIds.remove(item.book.id);
          } else {
            _selectedIds.add(item.book.id);
          }
        });
      },
      highlighted: highlighted,
      selected: selected,
      showSelection: true,
    );
  }

  Widget _buildEditBottomBar() {
    final enabled = _selectedIds.isNotEmpty;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: enabled ? _moveSelectedToGroup : null,
                icon: const Icon(Icons.drive_file_move_outlined),
                label: const Text('移动至分组'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: enabled ? _deleteSelected : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 拖拽时跟随手指的浮动卡片
class _DragFeedbackCard extends StatelessWidget {
  final String title;

  const _DragFeedbackCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 168,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(6),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final BookWithProgress item;
  final VoidCallback onTap;
  final bool selected;
  final bool showSelection;
  final bool highlighted;

  const _BookCard({
    required this.item,
    required this.onTap,
    this.selected = false,
    this.showSelection = false,
    this.highlighted = false,
  });

  static const _coverColors = [
    Color(0xFF5B7C99),
    Color(0xFF8A9A5B),
    Color(0xFFB0715E),
    Color(0xFF7B6D8D),
    Color(0xFF4E8069),
  ];

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    final percent = progress?.percent ?? 0;
    final cover = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _coverColors[item.book.id % _coverColors.length],
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6), bottom: Radius.circular(2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            child: Text(
              item.book.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.book.chapterCount} 章',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              LinearProgressIndicator(
                value: percent <= 0 ? null : percent.clamp(0, 1),
                minHeight: 2,
              ),
            ],
          ),
        ),
      ],
    );

    if (!showSelection) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: cover,
      );
    }

    // 编辑模式：外框高亮 + 左上角选中圈
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: highlighted
                      ? Theme.of(context).colorScheme.primary
                      : selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            left: -6,
            top: -6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: cover,
          ),
        ],
      ),
    );
  }
}
