import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class AgentProfile {
  const AgentProfile({
    required this.agentName,
    required this.agentEmail,
    required this.brokerageName,
    required this.brokerageAddress,
    required this.brokerageCityStateZip,
    required this.agentPhone,
    required this.state,
    required this.isMultiPersonFirm,
  });

  final String agentName;
  final String agentEmail;
  final String brokerageName;
  final String brokerageAddress;
  final String brokerageCityStateZip;
  final String agentPhone;
  final String state; // e.g. 'Colorado'
  final bool isMultiPersonFirm;

  factory AgentProfile.fromJson(Map<String, dynamic> d) => AgentProfile(
        agentName: d['agentName'] as String? ?? '',
        agentEmail: d['agentEmail'] as String? ?? '',
        brokerageName: d['brokerageName'] as String? ?? '',
        brokerageAddress: d['brokerageAddress'] as String? ?? '',
        brokerageCityStateZip: d['brokerageCityStateZip'] as String? ?? '',
        agentPhone: d['agentPhone'] as String? ?? '',
        state: d['state'] as String? ?? 'Colorado',
        isMultiPersonFirm: d['isMultiPersonFirm'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'agentName': agentName,
        'agentEmail': agentEmail,
        'brokerageName': brokerageName,
        'brokerageAddress': brokerageAddress,
        'brokerageCityStateZip': brokerageCityStateZip,
        'agentPhone': agentPhone,
        'state': state,
        'isMultiPersonFirm': isMultiPersonFirm,
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

// Supported states — add more as forms are sourced
const List<String> kSupportedStates = ['Colorado'];
