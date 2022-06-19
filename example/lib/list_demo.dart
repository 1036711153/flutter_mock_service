import 'package:flutter/material.dart';

class ListDemo extends StatefulWidget {
  const ListDemo({Key? key}) : super(key: key);

  @override
  State<ListDemo> createState() => _ListDemoState();
}

class _ListDemoState extends State<ListDemo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('这个是一个ListDemo'),
      ),
      body: _buildScrollView(),
    );
  }

  Widget buildSliverCellList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) {
          if (index % 3 == 0) {
            return Container(
              height: 80,
              width: 200,
              color: Colors.yellow,
            );
          }
          if (index % 3 == 1) {
            return Container(
              height: 80,
              width: 200,
              color: Colors.blue,
            );
          }
          return Container(
            height: 80,
            width: 200,
            color: Colors.red,
          );
        },
        childCount: 100,
      ),
    );
  }

  Widget _buildScrollView() {
    return CustomScrollView(
      slivers: [buildSliverCellList()],
    );
  }
}
