import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class AgentProfile {
  const AgentProfile({
    required this.agentName,
    required this.agentEmail,
    required this.brokerageName,
  });

  final String agentName;
  final String agentEmail;
  final String brokerageName;

  factory AgentProfile.fromJson(Map<String, dynamic> d) => AgentProfile(
        agentName: d['agentName'] as String? ?? '',
        agentEmail: d['agentEmail'] as String? ?? '',
        brokerageName: d['brokerageName'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'agentName': agentName,
        'agentEmail': agentEmail,
        'brokerageName': brokerageName,
      };
}

class AgentProfileStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/agent_profile.json');
  }

  Future<AgentProfile?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      return AgentProfile.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AgentProfile profile) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(profile.toJson()));
  }
}

final agentProfileStoreProvider =
    Provider<AgentProfileStore>((_) => AgentProfileStore());

final agentProfileProvider = FutureProvider<AgentProfile?>((ref) async {
  return ref.read(agentProfileStoreProvider).load();
});
