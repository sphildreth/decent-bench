import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/data_quality_controller.dart';
import '../../domain/data_quality_models.dart';

class ViolationBrowser extends StatefulWidget {
  const ViolationBrowser({
    super.key,
    required this.controller,
    required this.issue,
  });

  final DataQualityController controller;
  final ValidationIssueSummary issue;

  @override
  State<ViolationBrowser> createState() => _ViolationBrowserState();
}

class _ViolationBrowserState extends State<ViolationBrowser> {
  int pageIndex = 0;
  int pageSize = 50;
  late Future<List<ViolationRowReference>> pageFuture = _loadPage();

  Future<List<ViolationRowReference>> _loadPage() {
    return widget.controller.loadViolationPage(
      issue: widget.issue,
      pageSize: pageSize,
      pageIndex: pageIndex,
    );
  }

  void _reload() {
    setState(() {
      pageFuture = _loadPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                issue.ruleName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${issue.ruleType} | ${issue.severity.wireName} | ${issue.targetTable}.${issue.targetColumn ?? '*'} | ${issue.failureCount} failures',
              ),
              if (issue.sampleViolationRows.any(
                (row) => row.valueDisplay == null,
              ))
                const Text('Values hidden by report privacy setting'),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            TextButton.icon(
              onPressed: issue.detailQuerySql == null
                  ? null
                  : () => Clipboard.setData(
                      ClipboardData(text: issue.detailQuerySql!),
                    ),
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copy diagnostic SQL'),
            ),
            TextButton.icon(
              onPressed: () => Clipboard.setData(
                ClipboardData(
                  text:
                      '${issue.ruleName}: ${issue.failureCount} ${issue.issueCode}',
                ),
              ),
              icon: const Icon(Icons.summarize_outlined, size: 18),
              label: const Text('Copy issue summary'),
            ),
            TextButton.icon(
              onPressed: null,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Open filtered preview'),
            ),
            const SizedBox(width: 8),
            const Text('Page size'),
            DropdownButton<int>(
              value: pageSize,
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 50, child: Text('50')),
                DropdownMenuItem<int>(value: 100, child: Text('100')),
                DropdownMenuItem<int>(value: 500, child: Text('500')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                pageSize = value;
                pageIndex = 0;
                _reload();
              },
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<ViolationRowReference>>(
            future: pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data ?? const <ViolationRowReference>[];
              if (rows.isEmpty) {
                return const Center(
                  child: Text('No violation rows on this page.'),
                );
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      row.rowIdentity.entries
                          .map((entry) => '${entry.key}=${entry.value}')
                          .join(', '),
                    ),
                    subtitle: Text(row.valueDisplay ?? row.message),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text('Page ${pageIndex + 1}'),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Previous page',
                onPressed: pageIndex == 0
                    ? null
                    : () {
                        pageIndex--;
                        _reload();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: () {
                  pageIndex++;
                  _reload();
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
