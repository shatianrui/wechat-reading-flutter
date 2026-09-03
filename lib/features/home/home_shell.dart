import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../bookshelf/bookshelf_page.dart';
import '../profile/profile_page.dart';

/// 底部导航壳:书架 / 我。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [BookshelfPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.square_stack),
            selectedIcon: Icon(CupertinoIcons.square_stack_fill),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.person),
            selectedIcon: Icon(CupertinoIcons.person_fill),
            label: '我',
          ),
        ],
      ),
    );
  }
}
