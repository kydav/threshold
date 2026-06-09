import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'agreement_model.dart';

class AgreementRepository {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/agreements');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  File _file(Directory dir, String id) => File('${dir.path}/$id.json');

  Future<AgreementModel> create({
    required String agentId,
    required String agentName,
    required String agentEmail,
    required String brokerageName,
    required String buyerName,
    required String buyerEmail,
    required String propertyScope,
    required String compensation,
    required DateTime startDate,
    required DateTime endDate,
    String formState = 'Colorado',
  }) async {
    final model = AgreementModel(
      id: const Uuid().v4(),
      agentId: agentId,
      agentName: agentName,
      agentEmail: agentEmail,
      brokerageName: brokerageName,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      propertyScope: propertyScope,
      compensation: compensation,
      startDate: startDate,
      endDate: endDate,
      status: AgreementStatus.draft,
      createdAt: DateTime.now(),
      formState: formState,
    );
    await save(model);
    return model;
  }

  Future<void> save(AgreementModel model) async {
    final dir = await _dir();
    await _file(dir, model.id)
        .writeAsString(jsonEncode(model.toJson()));
  }

  Future<AgreementModel?> get(String id) async {
    final dir = await _dir();
    final file = _file(dir, id);
    if (!file.existsSync()) return null;
    return AgreementModel.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  }

  Future<List<AgreementModel>> listForAgent(String agentId) async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().toList();
    final results = <AgreementModel>[];
    for (final f in files) {
      try {
        final model = AgreementModel.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        if (model.agentId == agentId) results.add(model);
      } catch (_) {}
    }
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  Future<List<AgreementModel>> listPending(String agentId) async {
    final all = await listForAgent(agentId);
    return all.where((a) => a.isPendingDelivery).toList();
  }
}

final agreementRepositoryProvider =
    Provider<AgreementRepository>((_) => AgreementRepository());

// Notifier that holds the in-memory list and refreshes from disk.
class AgreementListNotifier
    extends AsyncNotifier<List<AgreementModel>> {
  @override
  Future<List<AgreementModel>> build() => _load();

  Future<List<AgreementModel>> _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return ref.read(agreementRepositoryProvider).listForAgent(uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final agreementListProvider =
    AsyncNotifierProvider<AgreementListNotifier, List<AgreementModel>>(
        AgreementListNotifier.new);
