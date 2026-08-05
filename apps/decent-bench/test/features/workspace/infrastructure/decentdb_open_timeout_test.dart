import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open-timeouts are wider than the default 30s to absorb slow '
      'process writer lock waits', () {
    expect(const DatabaseOpenSettings().toOpenOptionsFragment(),
        'profile=default,plan_cache_enabled=true');
    expect(
      const DatabaseOpenSettings(
        processCoordinationTimeoutMs: 60000,
      ).toOpenOptionsFragment(),
      'profile=default,plan_cache_enabled=true,'
      'process_coordination_timeout_ms=60000',
    );
  });

  test('databaseOpen TOML round-trips process_coordination_timeout_ms', () {
    final config = AppConfig.defaults().copyWith(
      databaseOpen: const DatabaseOpenSettings(
        processCoordinationTimeoutMs: 180000,
      ),
    );
    final toml = config.toToml();
    final parsed = AppConfig.fromToml(toml);
    expect(parsed.databaseOpen.processCoordinationTimeoutMs, 180000);
  });

  test('databaseOpen TOML round-trips open_bridge_timeout_ms', () {
    final config = AppConfig.defaults().copyWith(
      databaseOpen: const DatabaseOpenSettings(
        openBridgeTimeoutMs: 600000,
      ),
    );
    final toml = config.toToml();
    final parsed = AppConfig.fromToml(toml);
    expect(toml, contains('open_bridge_timeout_ms = 600000'));
    expect(parsed.databaseOpen.openBridgeTimeoutMs, 600000);
  });

  test('resolveOpenDatabaseTimeout returns the 5-minute default when env var '
      'is missing or unparseable', () {
    expect(DecentDbBridge.resolveOpenDatabaseTimeout(),
        const Duration(minutes: 5));
  });
}