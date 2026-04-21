import 'dart:io';

class DockerCli {
  static Future<bool> isDockerAvailable() async {
    try {
      final result = await Process.run('docker', ['info']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
