import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/data_quality_controller.dart';
import '../../domain/data_quality_models.dart';
import '../../domain/data_quality_rules.dart';

class ValidationProfileEditor extends StatefulWidget {
  const ValidationProfileEditor({super.key, required this.controller});

  final DataQualityController controller;

  @override
  State<ValidationProfileEditor> createState() =>
      _ValidationProfileEditorState();
}

class _ValidationProfileEditorState extends State<ValidationProfileEditor> {
  static const _profileTypeGroup = XTypeGroup(
    label: 'Quality profile',
    extensions: <String>['toml'],
  );

  QualityProfileDocument? editing;
  ValidationRule? selectedRule;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        editing ??=
            widget.controller.currentProfile ??
            QualityProfileDocument.empty(name: 'Quality profile');
        return Row(
          children: <Widget>[
            SizedBox(
              width: 280,
              child: _ProfileList(
                controller: widget.controller,
                selected: editing,
                onSelect: (profile) {
                  setState(() {
                    editing = profile;
                    selectedRule = profile.rules.firstOrNull;
                  });
                },
                onCreate: () {
                  setState(() {
                    editing = QualityProfileDocument.empty(
                      name: 'New quality profile',
                    );
                    selectedRule = null;
                  });
                },
                onDuplicate: editing == null
                    ? null
                    : () => widget.controller.duplicateProfile(editing!),
                onImport: () async {
                  final file = await openFile(
                    acceptedTypeGroups: const <XTypeGroup>[_profileTypeGroup],
                  );
                  if (file == null) {
                    return;
                  }
                  await widget.controller.importProfile(file.path);
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    editing = widget.controller.currentProfile;
                    selectedRule = editing?.rules.firstOrNull;
                  });
                },
                onExport: editing == null
                    ? null
                    : () async {
                        final location = await getSaveLocation(
                          suggestedName:
                              '${_safeProfileFileName(editing!.name)}.toml',
                          acceptedTypeGroups: const <XTypeGroup>[
                            _profileTypeGroup,
                          ],
                        );
                        if (location == null) {
                          return;
                        }
                        await widget.controller.exportProfile(
                          profile: editing!,
                          destinationPath: location.path,
                        );
                      },
                onDelete: editing == null
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete profile?'),
                            content: Text('Delete ${editing!.name}?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await widget.controller.deleteProfile(
                            editing!.profileId,
                          );
                          setState(
                            () => editing = widget.controller.currentProfile,
                          );
                        }
                      },
              ),
            ),
            VerticalDivider(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: _ProfileForm(
                profile: editing!,
                selectedRule: selectedRule,
                schemaTables: widget.controller.schema.tables
                    .map((table) => table.name)
                    .toList(),
                onChanged: (profile) => setState(() => editing = profile),
                onSelectRule: (rule) => setState(() => selectedRule = rule),
                onSave: () => widget.controller.saveProfile(editing!),
              ),
            ),
          ],
        );
      },
    );
  }

  String _safeProfileFileName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'quality-profile' : normalized;
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
    required this.onDuplicate,
    required this.onImport,
    required this.onExport,
    required this.onDelete,
  });

  final DataQualityController controller;
  final QualityProfileDocument? selected;
  final ValueChanged<QualityProfileDocument> onSelect;
  final VoidCallback onCreate;
  final VoidCallback? onDuplicate;
  final VoidCallback onImport;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Validation Profiles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Wrap(
          spacing: 4,
          children: <Widget>[
            IconButton(
              tooltip: 'Create profile',
              onPressed: onCreate,
              icon: const Icon(Icons.add_outlined),
            ),
            IconButton(
              tooltip: 'Duplicate profile',
              onPressed: onDuplicate,
              icon: const Icon(Icons.copy_outlined),
            ),
            IconButton(
              tooltip: 'Import profile',
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
            ),
            IconButton(
              tooltip: 'Export profile',
              onPressed: onExport,
              icon: const Icon(Icons.ios_share_outlined),
            ),
            IconButton(
              tooltip: 'Delete profile',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (final profile in controller.profiles)
                ListTile(
                  dense: true,
                  selected: selected?.profileId == profile.profileId,
                  title: Text(profile.name),
                  subtitle: Text('${profile.rules.length} rules'),
                  onTap: () => onSelect(profile),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.profile,
    required this.selectedRule,
    required this.schemaTables,
    required this.onChanged,
    required this.onSelectRule,
    required this.onSave,
  });

  final QualityProfileDocument profile;
  final ValidationRule? selectedRule;
  final List<String> schemaTables;
  final ValueChanged<QualityProfileDocument> onChanged;
  final ValueChanged<ValidationRule?> onSelectRule;
  final Future<void> Function() onSave;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final TextEditingController nameController = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController descriptionController =
      TextEditingController(text: widget.profile.description);

  @override
  void didUpdateWidget(covariant _ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.profileId != widget.profile.profileId) {
      nameController.text = widget.profile.name;
      descriptionController.text = widget.profile.description;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errors = widget.profile.validate();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (value) => widget.onChanged(
            widget.profile.copyWith(
              name: value,
              updatedAt: DateTime.now().toUtc(),
            ),
          ),
        ),
        TextField(
          controller: descriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          onChanged: (value) => widget.onChanged(
            widget.profile.copyWith(
              description: value,
              updatedAt: DateTime.now().toUtc(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Text('Rules', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: 'Add rule',
              onPressed: () {
                final rule = ValidationRule(
                  id: generateQualityUuid(),
                  name: 'Required value',
                  description: '',
                  enabled: true,
                  severity: QualitySeverity.error,
                  targetTable: widget.schemaTables.isEmpty
                      ? ''
                      : widget.schemaTables.first,
                  targetColumn: null,
                  ruleType: ValidationRuleType.required,
                  params: const <String, Object?>{
                    'trim_strings': true,
                    'treat_empty_string_as_null': true,
                  },
                );
                widget.onChanged(
                  widget.profile.copyWith(
                    rules: <ValidationRule>[...widget.profile.rules, rule],
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
                widget.onSelectRule(rule);
              },
              icon: const Icon(Icons.add_outlined),
            ),
          ],
        ),
        for (final rule in widget.profile.rules)
          ListTile(
            dense: true,
            selected: widget.selectedRule?.id == rule.id,
            leading: Switch(
              value: rule.enabled,
              onChanged: (value) => _replaceRule(rule.copyWith(enabled: value)),
            ),
            title: Text(rule.name),
            subtitle: Text('${rule.ruleType.wireName} | ${rule.targetTable}'),
            trailing: IconButton(
              tooltip: 'Delete rule',
              onPressed: () => widget.onChanged(
                widget.profile.copyWith(
                  rules: widget.profile.rules
                      .where((item) => item.id != rule.id)
                      .toList(),
                  updatedAt: DateTime.now().toUtc(),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
            ),
            onTap: () => widget.onSelectRule(rule),
          ),
        if (widget.selectedRule != null)
          _RuleForm(
            rule: widget.selectedRule!,
            schemaTables: widget.schemaTables,
            onChanged: _replaceRule,
          ),
        if (errors.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          for (final error in errors)
            Text(
              error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: errors.isEmpty ? widget.onSave : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Profile'),
        ),
      ],
    );
  }

  void _replaceRule(ValidationRule updated) {
    widget.onChanged(
      widget.profile.copyWith(
        rules: <ValidationRule>[
          for (final rule in widget.profile.rules)
            if (rule.id == updated.id) updated else rule,
        ],
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    widget.onSelectRule(updated);
  }
}

class _RuleForm extends StatelessWidget {
  const _RuleForm({
    required this.rule,
    required this.schemaTables,
    required this.onChanged,
  });

  final ValidationRule rule;
  final List<String> schemaTables;
  final ValueChanged<ValidationRule> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Rule Editor', style: Theme.of(context).textTheme.titleSmall),
          TextFormField(
            initialValue: rule.name,
            decoration: const InputDecoration(labelText: 'Rule name'),
            onChanged: (value) => onChanged(rule.copyWith(name: value)),
          ),
          DropdownButtonFormField<ValidationRuleType>(
            initialValue: rule.ruleType,
            decoration: const InputDecoration(labelText: 'Rule type'),
            items: <DropdownMenuItem<ValidationRuleType>>[
              for (final metadata in validationRuleMetadata)
                DropdownMenuItem<ValidationRuleType>(
                  value: metadata.type,
                  child: Text(metadata.label),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(
                  rule.copyWith(
                    ruleType: value,
                    params: const <String, Object?>{},
                  ),
                );
              }
            },
          ),
          DropdownButtonFormField<QualitySeverity>(
            initialValue: rule.severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: <DropdownMenuItem<QualitySeverity>>[
              for (final severity in QualitySeverity.values)
                DropdownMenuItem<QualitySeverity>(
                  value: severity,
                  child: Text(severity.wireName),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(rule.copyWith(severity: value));
              }
            },
          ),
          TextFormField(
            initialValue: rule.targetTable,
            decoration: const InputDecoration(labelText: 'Target table'),
            onChanged: (value) => onChanged(rule.copyWith(targetTable: value)),
          ),
          TextFormField(
            initialValue: rule.targetColumn ?? '',
            decoration: const InputDecoration(labelText: 'Target column'),
            onChanged: (value) => onChanged(
              rule.copyWith(targetColumn: value.trim().isEmpty ? null : value),
            ),
          ),
          TextFormField(
            initialValue: const JsonEncoder.withIndent(
              '  ',
            ).convert(rule.params),
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Parameters JSON',
              helperText:
                  'Use keys supported by the selected rule type. Invalid profiles cannot be saved.',
            ),
            onChanged: (value) {
              try {
                final decoded = jsonDecode(value);
                if (decoded is Map) {
                  onChanged(
                    rule.copyWith(params: Map<String, Object?>.from(decoded)),
                  );
                }
              } catch (_) {}
            },
          ),
          const SizedBox(height: 8),
          Text(
            metadataForRuleType(rule.ruleType).sqlBacked
                ? 'Generated SQL preview is available during execution.'
                : 'Runs in background isolate when it cannot be SQL-backed.',
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
