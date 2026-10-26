import 'package:flutter/material.dart';
import '../services/iptv_service.dart';
import 'player_screen.dart';

class IptvScreen extends StatefulWidget {
  const IptvScreen({super.key});
  @override
  State<IptvScreen> createState() => _IptvScreenState();
}

class _IptvScreenState extends State<IptvScreen> {
  final _service = IptvService();
  final _search = TextEditingController();
  IptvSource _selected = IptvService.sources.first;
  List<IptvChannel> _channels = [];
  bool _loading = false;
  String? _error;
  static const cyan = Color(0xFF29B6F6);
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _load() async {
    final source = _selected;
    setState(() { _loading = true; _error = null; _channels = []; });
    try {
      final channels = await _service.load(source);
      if (!mounted || _selected != source) return;
      setState(() => _channels = channels);
    } catch (e) {
      if (mounted && _selected == source) setState(() => _error = 'Não foi possível carregar a lista: $e');
    } finally {
      if (mounted && _selected == source) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final term = _search.text.toLowerCase().trim();
    final visible = term.isEmpty ? _channels : _channels.where((c) => c.name.toLowerCase().contains(term) || c.category.toLowerCase().contains(term)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF07101F),
      appBar: AppBar(title: const Text('IPTV'), backgroundColor: const Color(0xFF0B1728), foregroundColor: cyan,
        actions: [IconButton(tooltip: 'Atualizar canais', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        SizedBox(height: 55, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
          for (final source in IptvService.sources)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(source.name), selected: _selected == source,
              onSelected: (_) { setState(() => _selected = source); _load(); },
              selectedColor: cyan, backgroundColor: const Color(0xFF14263D), labelStyle: TextStyle(color: _selected == source ? Colors.black : Colors.white))),
        ])),
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _search, onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white), decoration: InputDecoration(prefixIcon: const Icon(Icons.search, color: cyan), hintText: 'Buscar canais', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF14263D), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
        if (_loading) const LinearProgressIndicator(color: cyan),
        if (_error != null) Padding(padding: const EdgeInsets.all(18), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Align(alignment: Alignment.centerLeft,
          child: Text('${visible.length} canais • ${_selected.name}', style: const TextStyle(color: Colors.white70)))),
        Expanded(child: ListView.builder(itemCount: visible.length, itemBuilder: (context, index) {
          final channel = visible[index];
          return ListTile(
            leading: SizedBox(width: 54, height: 48, child: channel.logo?.startsWith('https://') == true || channel.logo?.startsWith('http://') == true
              ? Image.network(channel.logo!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: cyan))
              : const Icon(Icons.live_tv, color: cyan)),
            title: Text(channel.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(channel.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.play_circle_outline, color: cyan),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlayerScreen(url: channel.url, contentTitle: channel.name, contentType: 'tv'))),
          );
        })),
      ]),
    );
  }
}
