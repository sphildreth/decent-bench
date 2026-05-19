import 'workspace_models.dart';

enum SqlRiskLevel {
  readOnly,
  mutating,
  destructive,
  transactionControl,
  unknown,
}

class SqlRiskAssessment {
  const SqlRiskAssessment({
    required this.level,
    required this.leadingKeyword,
    required this.reason,
  });

  final SqlRiskLevel level;
  final String? leadingKeyword;
  final String reason;

  bool get requiresConfirmation {
    return switch (level) {
      SqlRiskLevel.destructive || SqlRiskLevel.mutating => true,
      SqlRiskLevel.readOnly ||
      SqlRiskLevel.transactionControl ||
      SqlRiskLevel.unknown => false,
    };
  }

  bool get isDestructive => level == SqlRiskLevel.destructive;
}

SqlRiskAssessment assessSqlRisk(String sql, {QueryContract? contract}) {
  final keyword = leadingSqlKeyword(sql);
  if (keyword == null) {
    return const SqlRiskAssessment(
      level: SqlRiskLevel.unknown,
      leadingKeyword: null,
      reason: 'No SQL statement keyword was detected.',
    );
  }

  if (_transactionControlKeywords.contains(keyword)) {
    return SqlRiskAssessment(
      level: SqlRiskLevel.transactionControl,
      leadingKeyword: keyword,
      reason: '$keyword controls transaction state.',
    );
  }

  if (_destructiveKeywords.contains(keyword)) {
    return SqlRiskAssessment(
      level: SqlRiskLevel.destructive,
      leadingKeyword: keyword,
      reason: '$keyword may remove data or schema objects.',
    );
  }

  if (_mutatingKeywords.contains(keyword)) {
    return SqlRiskAssessment(
      level: SqlRiskLevel.mutating,
      leadingKeyword: keyword,
      reason: '$keyword may change data or schema state.',
    );
  }

  if (contract != null && !contract.readOnly) {
    return SqlRiskAssessment(
      level: SqlRiskLevel.mutating,
      leadingKeyword: keyword,
      reason: 'The query contract reports a non-read-only statement.',
    );
  }

  if (_readOnlyKeywords.contains(keyword) || contract?.readOnly == true) {
    return SqlRiskAssessment(
      level: SqlRiskLevel.readOnly,
      leadingKeyword: keyword,
      reason: '$keyword is treated as read-only.',
    );
  }

  return SqlRiskAssessment(
    level: SqlRiskLevel.unknown,
    leadingKeyword: keyword,
    reason: 'Risk for $keyword is unknown.',
  );
}

String? leadingSqlKeyword(String sql) {
  final match = RegExp(
    r'^(?:\s|--[^\r\n]*(?:\r?\n|$)|/\*[\s\S]*?\*/)*([A-Za-z]+)',
    caseSensitive: false,
  ).firstMatch(sql);
  return match?.group(1)?.toUpperCase();
}

const Set<String> _readOnlyKeywords = <String>{
  'EXPLAIN',
  'PRAGMA',
  'SELECT',
  'VALUES',
  'WITH',
};

const Set<String> _transactionControlKeywords = <String>{
  'BEGIN',
  'COMMIT',
  'RELEASE',
  'ROLLBACK',
  'SAVEPOINT',
};

const Set<String> _mutatingKeywords = <String>{
  'ALTER',
  'CREATE',
  'INSERT',
  'REINDEX',
  'REPLACE',
  'UPDATE',
  'VACUUM',
};

const Set<String> _destructiveKeywords = <String>{'DELETE', 'DROP', 'TRUNCATE'};
