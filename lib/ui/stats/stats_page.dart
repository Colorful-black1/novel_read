/// 阅读统计页：今日/累计时长与字数、近 7 天明细。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/models.dart';
import '../../logic/providers.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  List<ReadingStat>? _stats;
  ReadingStat? _total;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(statsRepositoryProvider);
      final result = await Future.wait([repo.listAll(), repo.getTotal()]);
      if (!mounted) return;
      setState(() {
        _stats = result[0] as List<ReadingStat>;
        _total = result[1] as ReadingStat;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('加载失败：$_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    // 底部留白：主框架 extendBody 后内容会延伸到透明导航栏后面
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildRecentList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final today = _stats != null && _stats!.isNotEmpty ? _stats!.first : null;
    // listAll 按日期倒序，第一条即最近一天；若最近一天不是今天则今日为零
    final todayStat = (today != null && today.date == _todayKey())
        ? today
        : const ReadingStat(date: '');
    final total = _total ?? const ReadingStat(date: '');
    return Row(
      children: [
        _SummaryCard(
            icon: Icons.access_time,
            label: '今日时长',
            value: formatDuration(todayStat.durationMs),
            color: const Color(0xFF5B7C99)),
        const SizedBox(width: 12),
        _SummaryCard(
            icon: Icons.timer_outlined,
            label: '累计时长',
            value: formatDuration(total.durationMs),
            color: const Color(0xFF7C9C6B)),
        const SizedBox(width: 12),
        _SummaryCard(
            icon: Icons.text_fields,
            label: '累计字数',
            value: formatCount(total.charCount),
            color: const Color(0xFFB08968)),
      ],
    );
  }

  Widget _buildRecentList() {
    final stats = _stats ?? const <ReadingStat>[];
    final recent = stats.length > 7 ? stats.sublist(0, 7) : stats;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('近 ${recent.length} 天',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无阅读记录'),
            )
          else
            for (final s in recent)
              ListTile(
                dense: true,
                leading: Text(_shortDate(s.date),
                    style: Theme.of(context).textTheme.bodySmall),
                title: Text(formatDuration(s.durationMs)),
                trailing: Text('${formatCount(s.charCount)} 字',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
        ],
      ),
    );
  }

  String _todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _shortDate(String date) {
    // YYYY-MM-DD → MM-DD
    final parts = date.split('-');
    return parts.length == 3 ? '${parts[1]}-${parts[2]}' : date;
  }
}

/// 时长格式化：毫秒 → X小时Y分 / Y分 / Z秒
String formatDuration(int ms) {
  final totalSec = ms ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) return '$h小时$m分';
  if (m > 0) return '$m分$s秒';
  return '$s秒';
}

/// 字数格式化：大数用「万」
String formatCount(int count) {
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)}万';
  }
  return count.toString();
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
