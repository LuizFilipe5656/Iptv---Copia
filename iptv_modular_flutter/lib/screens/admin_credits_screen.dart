import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCreditsScreen extends StatefulWidget {
  final Map<String, dynamic> reseller;

  const AdminCreditsScreen({
    super.key,
    required this.reseller,
  });

  @override
  State<AdminCreditsScreen> createState() => _AdminCreditsScreenState();
}

class _AdminCreditsScreenState extends State<AdminCreditsScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _history;

  int balance = 0;
  bool saving = false;
  bool adding = true;

  @override
  void initState() {
    super.initState();

    balance = (widget.reseller['credits'] as num?)?.toInt() ?? 0;
    _history = _loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final response = await Supabase.instance.client.rpc(
      'admin_get_credit_history',
      params: {
        'p_reseller_id': widget.reseller['id'],
      },
    );

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _refresh() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_admin_users',
      );

      final users = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final resellerId = widget.reseller['id'].toString();

      final current = users.where(
        (user) => user['id'].toString() == resellerId,
      );

      if (!mounted) return;

      setState(() {
        if (current.isNotEmpty) {
          balance = (current.first['credits'] as num?)?.toInt() ?? 0;
        }

        _history = _loadHistory();
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (saving) return;

    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0 || amount > 1000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma quantidade entre 1 e 1000000.'),
        ),
      );
      return;
    }

    final signedAmount = adding ? amount : -amount;

    if (signedAmount < 0 && amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo insuficiente.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar movimentacao'),
        content: Text(
          '${adding ? "Adicionar" : "Retirar"} $amount creditos '
          'do revendedor ${widget.reseller["name"] ?? "sem nome"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => saving = true);

    try {
      final response = await Supabase.instance.client.rpc(
        'admin_adjust_reseller_credits',
        params: {
          'p_reseller_id': widget.reseller['id'],
          'p_amount': signedAmount,
          'p_description': _descriptionController.text.trim(),
        },
      );

      if (!mounted) return;

      setState(() {
        balance = (response as num).toInt();
      });

      _amountController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creditos atualizados com sucesso.'),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao movimentar creditos: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '-';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, "0")}/'
        '${local.month.toString().padLeft(2, "0")}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, "0")}:'
        '${local.minute.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final resellerName = widget.reseller['name']?.toString() ?? 'Revendedor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar creditos'),
        actions: [
          IconButton(
            onPressed: saving ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    resellerName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Saldo atual'),
                  Text(
                    '$balance',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.add_circle_outline),
                label: Text('Adicionar'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.remove_circle_outline),
                label: Text('Retirar'),
              ),
            ],
            selected: {adding},
            onSelectionChanged: saving
                ? null
                : (selection) {
                    setState(() => adding = selection.first);
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            enabled: !saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantidade de creditos',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !saving,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(
              saving ? 'Salvando...' : 'Confirmar movimentacao',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Historico de movimentacoes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Text('Erro no historico: ${snapshot.error}');
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return const Text(
                  'Nenhuma movimentacao registrada ainda.',
                );
              }

              return Column(
                children: items.map((item) {
                  final amount = (item['amount'] as num?)?.toInt() ?? 0;

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                        color: amount >= 0 ? Colors.green : Colors.redAccent,
                      ),
                      title: Text(
                        '${amount > 0 ? "+" : ""}$amount creditos',
                      ),
                      subtitle: Text(
                        '${_dateLabel(item["created_at"])}\n'
                        'Admin: ${item["admin_name"] ?? "N/A"}\n'
                        'Saldo: ${item["balance_before"]} '
                        '-> ${item["balance_after"]}\n'
                        '${item["description"] ?? ""}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
