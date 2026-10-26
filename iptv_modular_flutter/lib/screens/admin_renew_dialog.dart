import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRenewDialog extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminRenewDialog({
    super.key,
    required this.user,
  });

  @override
  State<AdminRenewDialog> createState() => _AdminRenewDialogState();
}

class _AdminRenewDialogState extends State<AdminRenewDialog> {
  static const plans = ['FREE', 'PREMIUM', 'DIAMANTE'];

  late String selectedPlan;
  late DateTime selectedDate;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final currentPlan = widget.user['plan']?.toString() ?? '';

    selectedPlan = plans.contains(currentPlan) ? currentPlan : 'FREE';

    final currentDate = DateTime.tryParse(
      widget.user['expiration_date']?.toString() ?? '',
    )?.toLocal();

    final tomorrow = DateTime.now().add(
      const Duration(days: 1),
    );

    selectedDate = currentDate != null && currentDate.isAfter(tomorrow)
        ? currentDate
        : tomorrow;
  }

  Future<void> chooseDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final lastDate = DateTime(
      today.year + 10,
      today.month,
      today.day,
    );

    final initialDate =
        selectedDate.isAfter(lastDate) ? lastDate : selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> save() async {
    final userId = widget.user['id']?.toString();

    if (userId == null || userId.isEmpty || saving) {
      return;
    }

    setState(() => saving = true);

    try {
      final expiration = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        23,
        59,
        59,
      );

      await Supabase.instance.client.rpc(
        'admin_renew_subscription',
        params: {
          'p_user_id': userId,
          'p_plan': selectedPlan,
          'p_expiration_date': expiration.toUtc().toIso8601String(),
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao renovar: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? widget.user['email'] ?? 'Usuario';

    final dateLabel = '${selectedDate.day.toString().padLeft(2, "0")}/'
        '${selectedDate.month.toString().padLeft(2, "0")}/'
        '${selectedDate.year}';

    return AlertDialog(
      title: const Text('Renovar assinatura'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toString()),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedPlan,
            decoration: const InputDecoration(
              labelText: 'Plano',
              border: OutlineInputBorder(),
            ),
            items: plans.map((plan) {
              return DropdownMenuItem(
                value: plan,
                child: Text(plan),
              );
            }).toList(),
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => selectedPlan = value);
                    }
                  },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: saving ? null : chooseDate,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Escolher vencimento'),
          ),
          const SizedBox(height: 8),
          Text('Vencimento: $dateLabel'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Salvar renovacao'),
        ),
      ],
    );
  }
}
