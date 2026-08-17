import 'package:flutter/material.dart';

class EmptySearchState extends StatelessWidget {
  const EmptySearchState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No Results Found'),
    );
  }
}