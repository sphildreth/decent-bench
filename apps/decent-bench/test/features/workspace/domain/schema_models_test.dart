import 'package:decent_bench/features/workspace/domain/schema_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchemaColumn', () {
    test('round-trips autoIncrement and references through fromMap', () {
      final column = SchemaColumn.fromMap(<String, Object?>{
        'name': 'id',
        'type': 'INTEGER',
        'notNull': true,
        'unique': false,
        'primaryKey': true,
        'autoIncrement': true,
        'refTable': 'users',
        'refColumn': 'id',
        'refOnDelete': 'CASCADE',
        'refOnUpdate': 'NO ACTION',
      });

      expect(column.autoIncrement, isTrue);
      expect(column.hasForeignKey, isTrue);
      expect(column.refTable, 'users');
      expect(column.refOnDelete, 'CASCADE');
      expect(column.refOnUpdate, 'NO ACTION');
    });

    test('defaults autoIncrement to false when missing', () {
      final column = SchemaColumn.fromMap(<String, Object?>{
        'name': 'id',
        'type': 'INTEGER',
        'notNull': true,
        'unique': false,
        'primaryKey': true,
      });

      expect(column.autoIncrement, isFalse);
    });
  });

  group('SchemaForeignKey', () {
    test('round-trips composite foreign keys', () {
      final foreignKey = SchemaForeignKey.fromMap(<String, Object?>{
        'name': 'fk_order_customer',
        'columns': <String>['tenant_id', 'customer_id'],
        'referencedTable': 'customers',
        'referencedColumns': <String>['tenant_id', 'id'],
        'onDelete': 'CASCADE',
        'onUpdate': null,
      });

      expect(foreignKey.name, 'fk_order_customer');
      expect(foreignKey.columns, <String>['tenant_id', 'customer_id']);
      expect(foreignKey.referencedColumns, <String>['tenant_id', 'id']);
      expect(foreignKey.summary, contains('fk_order_customer'));
      expect(foreignKey.summary, contains('tenant_id, customer_id'));
      expect(foreignKey.summary, contains('ON DELETE CASCADE'));
    });

    test('summary is anonymous when name is missing', () {
      final foreignKey = SchemaForeignKey.fromMap(<String, Object?>{
        'columns': <String>['a'],
        'referencedTable': 't',
        'referencedColumns': <String>['id'],
      });

      expect(foreignKey.summary, startsWith('FK ('));
    });
  });

  group('SchemaObjectSummary', () {
    test('round-trips rowCount, primaryKeyColumns, foreignKeys for tables',
        () {
      final summary = SchemaObjectSummary.fromMap(<String, Object?>{
        'name': 'orders',
        'kind': 'table',
        'temporary': false,
        'ddl': 'CREATE TABLE orders (...);',
        'rowCount': 1024,
        'primaryKeyColumns': <String>['id'],
        'foreignKeys': <Map<String, Object?>>[
          <String, Object?>{
            'name': 'fk_orders_user',
            'columns': <String>['user_id'],
            'referencedTable': 'users',
            'referencedColumns': <String>['id'],
            'onDelete': 'CASCADE',
            'onUpdate': null,
          },
        ],
        'columns': <Map<String, Object?>>[
          <String, Object?>{
            'name': 'id',
            'type': 'INTEGER',
            'notNull': true,
            'unique': false,
            'primaryKey': true,
          },
          <String, Object?>{
            'name': 'user_id',
            'type': 'INTEGER',
            'notNull': true,
            'unique': false,
            'primaryKey': false,
          },
        ],
        'checks': <Map<String, Object?>>[],
      });

      expect(summary.isTable, isTrue);
      expect(summary.rowCount, 1024);
      expect(summary.primaryKeyColumns, <String>['id']);
      expect(summary.foreignKeys, hasLength(1));
      expect(summary.foreignKeys.first.summary, contains('fk_orders_user'));
    });

    test('round-trips sqlText and viewDependencies for views', () {
      final summary = SchemaObjectSummary.fromMap(<String, Object?>{
        'name': 'recent_orders',
        'kind': 'view',
        'temporary': false,
        'ddl': 'CREATE VIEW recent_orders AS SELECT * FROM orders;',
        'sqlText': 'SELECT * FROM orders WHERE id > 100',
        'viewDependencies': <String>['orders'],
        'columns': <Map<String, Object?>>[],
      });

      expect(summary.isView, isTrue);
      expect(summary.sqlText, 'SELECT * FROM orders WHERE id > 100');
      expect(summary.viewDependencies, <String>['orders']);
    });

    test('exposes rowCount as null when not provided', () {
      final summary = SchemaObjectSummary.fromMap(<String, Object?>{
        'name': 'x',
        'kind': 'view',
        'ddl': 'CREATE VIEW x AS SELECT 1;',
        'columns': <Map<String, Object?>>[],
      });

      expect(summary.rowCount, isNull);
      expect(summary.primaryKeyColumns, isEmpty);
      expect(summary.foreignKeys, isEmpty);
      expect(summary.viewDependencies, isEmpty);
    });
  });

  group('IndexSummary', () {
    test('round-trips includeColumns and fresh', () {
      final index = IndexSummary.fromMap(<String, Object?>{
        'name': 'idx_orders_user',
        'table': 'orders',
        'columns': <String>['user_id'],
        'includeColumns': <String>['total'],
        'unique': false,
        'kind': 'btree',
        'temporary': false,
        'fresh': false,
        'ddl': 'CREATE INDEX idx_orders_user ON orders (user_id) INCLUDE (total);',
      });

      expect(index.includeColumns, <String>['total']);
      expect(index.fresh, isFalse);
    });

    test('defaults includeColumns to empty and fresh to true', () {
      final index = IndexSummary.fromMap(<String, Object?>{
        'name': 'idx_orders_user',
        'table': 'orders',
        'columns': <String>['user_id'],
        'unique': false,
        'kind': 'btree',
      });

      expect(index.includeColumns, isEmpty);
      expect(index.fresh, isTrue);
    });
  });
}
