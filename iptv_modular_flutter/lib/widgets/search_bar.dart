import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.controller,
    this.onSubmitted,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Buscar filmes e séries',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
    );
  }
}
