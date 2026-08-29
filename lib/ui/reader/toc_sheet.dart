/// 目录选择浮层。
library;

import 'package:flutter/material.dart';

import '../../data/model/models.dart';

class TocSheet extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final Color foreground;
  final Color background;
  final ValueChanged<int> onSelect;

  const TocSheet({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.foreground,
    required this.background,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('目录（${chapters.length} 章）',
                    style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: foreground),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (ctx, i) {
                final current = i == currentIndex;
                return ListTile(
                  dense: true,
                  selected: current,
                  selectedTileColor: Colors.blueAccent.withValues(alpha: 0.15),
                  title: Text(
                    chapters[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current ? Colors.blueAccent : foreground,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
