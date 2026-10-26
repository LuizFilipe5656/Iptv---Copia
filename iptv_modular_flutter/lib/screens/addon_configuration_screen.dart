import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../services/addon_configuration_service.dart';

class AddonConfigurationScreen extends StatefulWidget {
  const AddonConfigurationScreen({
    super.key,
    required this.addon,
    required this.manifest,
    required this.initialValues,
    required this.configurationService,
  });

  final Addon addon;
  final StremioAddonManifest manifest;
  final Map<String, String> initialValues;
  final AddonConfigurationService configurationService;

  @override
  State<AddonConfigurationScreen> createState() =>
      _AddonConfigurationScreenState();
}

class _AddonConfigurationScreenState extends State<AddonConfigurationScreen> {
  late final Map<String, String> _values;
  final Map<String, TextEditingController> _controllers = {};
  late final List<_GenericParameter> _genericParameters;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _values = Map.of(widget.initialValues);
    _genericParameters = [
      for (final entry in _values.entries)
        _GenericParameter(key: entry.key, value: entry.value),
    ];
    if (widget.manifest.configuration.isEmpty && _genericParameters.isEmpty) {
      _genericParameters.add(_GenericParameter());
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final parameter in _genericParameters) {
      parameter.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(StremioAddonConfiguration field) =>
      _controllers.putIfAbsent(
        field.key,
        () => TextEditingController(text: _values[field.key] ?? ''),
      );

  Future<void> _install() async {
    final fields = widget.manifest.configuration;
    if (fields.isEmpty && !_validateGenericParameters()) return;
    for (final field in fields) {
      final value = _values[field.key] ?? '';
      if (field.isRequired && value.trim().isEmpty) {
        _showMessage('${field.title} é obrigatório.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await widget.configurationService.install(
        addon: widget.addon,
        manifest: widget.manifest,
        values: _values,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('Falha ao instalar addon configurado: $error');
      }
    }
  }

  bool _validateGenericParameters() {
    final keys = <String>{};
    var hasParameter = false;
    for (final parameter in _genericParameters) {
      final key = parameter.keyController.text.trim();
      final value = parameter.valueController.text.trim();
      if (key.isEmpty && value.isEmpty) continue;
      if (key.isEmpty || value.isEmpty) {
        _showMessage('Preencha o nome e o valor de cada parâmetro.');
        return false;
      }
      if (!keys.add(key)) {
        _showMessage('O parâmetro "$key" foi informado mais de uma vez.');
        return false;
      }
      hasParameter = true;
    }
    if (!hasParameter) {
      _showMessage('Adicione pelo menos um parâmetro de configuração.');
      return false;
    }
    return true;
  }

  void _syncGenericParameter(_GenericParameter parameter) {
    if (parameter.currentKey.isNotEmpty) {
      _values.remove(parameter.currentKey);
    }
    parameter.currentKey = parameter.keyController.text.trim();
    if (parameter.currentKey.isNotEmpty) {
      _values[parameter.currentKey] = parameter.valueController.text;
    }
  }

  void _addGenericParameter() {
    setState(() => _genericParameters.add(_GenericParameter()));
  }

  void _removeGenericParameter(_GenericParameter parameter) {
    setState(() {
      _genericParameters.remove(parameter);
      if (parameter.currentKey.isNotEmpty) {
        _values.remove(parameter.currentKey);
      }
      parameter.dispose();
      if (_genericParameters.isEmpty) {
        _genericParameters.add(_GenericParameter());
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.manifest.configuration;
    return Scaffold(
      appBar: AppBar(title: Text('Configurar ${widget.addon.name}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Escolha as opções que serão usadas para instalar este addon.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (fields.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 12),
                  child: Text(
                    'Este addon não publicou um esquema de opções. Informe '
                    'os parâmetros aceitos pelo provedor para compor o URL '
                    'configurado.',
                  ),
                ),
                for (final parameter in _genericParameters)
                  _genericParameterEditor(parameter),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addGenericParameter,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar parâmetro'),
                  ),
                ),
              ],
            ),
          for (final field in fields) ...[
            const SizedBox(height: 16),
            _buildField(field),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _install,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_saving ? 'Instalando...' : 'Instalar addon'),
          ),
        ],
      ),
    );
  }

  Widget _genericParameterEditor(_GenericParameter parameter) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: parameter.keyController,
                  decoration: const InputDecoration(labelText: 'Parâmetro'),
                  onChanged: (_) => _syncGenericParameter(parameter),
                ),
                TextField(
                  controller: parameter.valueController,
                  decoration: const InputDecoration(labelText: 'Valor'),
                  onChanged: (_) => _syncGenericParameter(parameter),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover parâmetro',
            onPressed: () => _removeGenericParameter(parameter),
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      );

  Widget _buildField(StremioAddonConfiguration field) {
    final type = field.type.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final isMulti = field.isMultiple ||
        const {'multiselect', 'checkboxes'}.contains(type) ||
        (type == 'checkbox' && field.options.isNotEmpty);

    if (const {'switch', 'boolean', 'bool'}.contains(type) ||
        (type == 'checkbox' && field.options.isEmpty)) {
      final tile = type == 'checkbox'
          ? CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(field.title),
              subtitle: field.isRequired ? const Text('Obrigatório') : null,
              value: _isTrue(_values[field.key] ?? field.defaultValue),
              onChanged: (value) => setState(
                () => _values[field.key] = (value ?? false).toString(),
              ),
            )
          : SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(field.title),
              subtitle: field.isRequired ? const Text('Obrigatório') : null,
              value: _isTrue(_values[field.key] ?? field.defaultValue),
              onChanged: (value) =>
                  setState(() => _values[field.key] = value.toString()),
            );
      return tile;
    }

    if (field.options.isNotEmpty && isMulti) {
      final selected = (_values[field.key] ?? field.defaultValue)
          .split(',')
          .where((value) => value.isNotEmpty)
          .toSet();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.title, style: Theme.of(context).textTheme.titleSmall),
          for (final option in field.options)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(option),
              value: selected.contains(option),
              onChanged: (checked) {
                setState(() {
                  final updated = {...selected};
                  if (checked == true) {
                    updated.add(option);
                  } else {
                    updated.remove(option);
                  }
                  _values[field.key] = updated.join(',');
                });
              },
            ),
        ],
      );
    }

    if (field.options.isNotEmpty &&
        const {'radio', 'radiogroup'}.contains(type)) {
      final selected = _values[field.key] ?? field.defaultValue;
      return RadioGroup<String>(
        groupValue: field.options.contains(selected) ? selected : null,
        onChanged: (value) {
          if (value != null) setState(() => _values[field.key] = value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.title, style: Theme.of(context).textTheme.titleSmall),
            for (final option in field.options)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(option),
                value: option,
              ),
          ],
        ),
      );
    }

    if (field.options.isNotEmpty) {
      final selected = _values[field.key] ?? field.defaultValue;
      return DropdownButtonFormField<String>(
        initialValue: field.options.contains(selected) ? selected : null,
        decoration: InputDecoration(
          labelText: field.title,
          helperText: field.isRequired ? 'Obrigatório' : null,
        ),
        items: [
          for (final option in field.options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _values[field.key] = value);
        },
      );
    }

    final isSecret = const {
      'password',
      'apikey',
      'secret',
      'token',
    }.contains(type);
    return TextField(
      controller: _controller(field),
      obscureText: isSecret,
      decoration: InputDecoration(
        labelText: field.title,
        helperText: field.isRequired ? 'Obrigatório' : null,
      ),
      onChanged: (value) => _values[field.key] = value,
    );
  }

  bool _isTrue(String value) =>
      const {'true', '1', 'yes', 'on'}.contains(value.toLowerCase());
}

class _GenericParameter {
  _GenericParameter({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value),
        currentKey = key;

  final TextEditingController keyController;
  final TextEditingController valueController;
  String currentKey;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
