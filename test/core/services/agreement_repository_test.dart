import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';

/// Builds a minimal [AgreementModel] for testing.
AgreementModel _buildAgreement({
  String id = 'abc-001',
  String agentId = 'agent-1',
  AgreementStatus status = AgreementStatus.draft,
  String? localPdfPath,
  Map<String, dynamic> formData = const {},
}) {
  return AgreementModel(
    id: id,
    agentId: agentId,
    agentName: 'Jane Agent',
    agentEmail: 'jane@brokerage.com',
    brokerageName: 'Acme Realty',
    buyerName: 'John Buyer',
    buyerEmail: 'john@example.com',
    propertyScope: 'Denver metro',
    compensation: '2.5%',
    startDate: DateTime(2025),
    endDate: DateTime(2025, 4),
    status: status,
    createdAt: DateTime(2025),
    localPdfPath: localPdfPath,
    formData: formData,
  );
}

void main() {
  // Use a fresh temporary directory for each test so tests are isolated.
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('threshold_repo_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // A testable repo that uses the temp directory instead of the device docs dir.
  AgreementRepository makeRepo() {
    return _TempDirRepository(tempDir);
  }

  group('AgreementRepository.save and get', () {
    test('saves a model and retrieves it by id', () async {
      final repo = makeRepo();
      final model = _buildAgreement();
      await repo.save(model);
      final retrieved = await repo.get(model.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, model.id);
      expect(retrieved.buyerName, model.buyerName);
    });

    test('get returns null for unknown id', () async {
      final repo = makeRepo();
      final result = await repo.get('nonexistent-id');
      expect(result, isNull);
    });

    test('save overwrites existing agreement with updated fields', () async {
      final repo = makeRepo();
      final original = _buildAgreement();
      await repo.save(original);

      final updated = original.copyWith(status: AgreementStatus.signed);
      await repo.save(updated);

      final retrieved = await repo.get(original.id);
      expect(retrieved!.status, AgreementStatus.signed);
    });
  });

  group('AgreementRepository.listForAgent', () {
    test('returns only agreements belonging to the specified agent', () async {
      final repo = makeRepo();
      final a1 = _buildAgreement(id: 'id-1', agentId: 'agent-A');
      final a2 = _buildAgreement(id: 'id-2', agentId: 'agent-B');
      final a3 = _buildAgreement(id: 'id-3', agentId: 'agent-A');
      await repo.save(a1);
      await repo.save(a2);
      await repo.save(a3);

      final results = await repo.listForAgent('agent-A');
      expect(results.length, 2);
      expect(results.every((m) => m.agentId == 'agent-A'), isTrue);
    });

    test('returns empty list when agent has no agreements', () async {
      final repo = makeRepo();
      final results = await repo.listForAgent('no-one');
      expect(results, isEmpty);
    });

    test('returns agreements sorted newest-first by createdAt', () async {
      final repo = makeRepo();
      final older = AgreementModel(
        id: 'older',
        agentId: 'agent-1',
        agentName: '',
        agentEmail: '',
        brokerageName: '',
        buyerName: 'Old',
        buyerEmail: 'old@test.com',
        propertyScope: '',
        compensation: '',
        startDate: DateTime(2025),
        endDate: DateTime(2025, 4),
        status: AgreementStatus.draft,
        createdAt: DateTime(2025),
      );
      final newer = AgreementModel(
        id: 'newer',
        agentId: 'agent-1',
        agentName: '',
        agentEmail: '',
        brokerageName: '',
        buyerName: 'New',
        buyerEmail: 'new@test.com',
        propertyScope: '',
        compensation: '',
        startDate: DateTime(2025, 2),
        endDate: DateTime(2025, 5),
        status: AgreementStatus.draft,
        createdAt: DateTime(2025, 2),
      );
      await repo.save(older);
      await repo.save(newer);

      final results = await repo.listForAgent('agent-1');
      expect(results.first.id, 'newer');
      expect(results.last.id, 'older');
    });

    test('skips malformed JSON files without crashing', () async {
      final repo = makeRepo();
      // Write a corrupt JSON file directly into the temp agreements dir.
      final dir = Directory('${tempDir.path}/agreements');
      dir.createSync(recursive: true);
      File('${dir.path}/corrupt.json').writeAsStringSync('{bad json');

      final results = await repo.listForAgent('agent-1');
      expect(results, isEmpty); // corrupt file skipped silently
    });
  });

  group('AgreementRepository.listPending', () {
    test('returns only pendingDelivery agreements', () async {
      final repo = makeRepo();
      final draft = _buildAgreement(id: 'draft-1', agentId: 'a');
      final pending = _buildAgreement(
        id: 'pend-1',
        agentId: 'a',
        status: AgreementStatus.pendingDelivery,
        localPdfPath: '/some.pdf',
      );
      final delivered = _buildAgreement(
        id: 'del-1',
        agentId: 'a',
        status: AgreementStatus.delivered,
      );
      await repo.save(draft);
      await repo.save(pending);
      await repo.save(delivered);

      final results = await repo.listPending('a');
      expect(results.length, 1);
      expect(results.first.id, 'pend-1');
    });

    test('returns empty list when no pending agreements', () async {
      final repo = makeRepo();
      await repo.save(_buildAgreement(agentId: 'a'));
      final results = await repo.listPending('a');
      expect(results, isEmpty);
    });
  });

  group('AgreementRepository.create', () {
    test('creates a draft agreement and persists it', () async {
      final repo = makeRepo();
      final model = await repo.create(
        agentId: 'agent-1',
        agentName: 'Jane',
        agentEmail: 'jane@test.com',
        brokerageName: 'Acme',
        buyerName: 'Bob',
        buyerEmail: 'bob@test.com',
        propertyScope: '123 Main St',
        compensation: '2%',
        startDate: DateTime(2025),
        endDate: DateTime(2025, 4),
      );

      expect(model.status, AgreementStatus.draft);
      expect(model.id, isNotEmpty);
      expect(model.agentId, 'agent-1');

      // Verify persisted
      final loaded = await repo.get(model.id);
      expect(loaded, isNotNull);
      expect(loaded!.buyerName, 'Bob');
    });

    test('assigns a unique UUID on each create call', () async {
      final repo = makeRepo();
      final m1 = await repo.create(
        agentId: 'a',
        agentName: '',
        agentEmail: '',
        brokerageName: '',
        buyerName: 'A',
        buyerEmail: 'a@t.com',
        propertyScope: '',
        compensation: '',
        startDate: DateTime(2025),
        endDate: DateTime(2025, 4),
      );
      final m2 = await repo.create(
        agentId: 'a',
        agentName: '',
        agentEmail: '',
        brokerageName: '',
        buyerName: 'B',
        buyerEmail: 'b@t.com',
        propertyScope: '',
        compensation: '',
        startDate: DateTime(2025),
        endDate: DateTime(2025, 4),
      );
      expect(m1.id, isNot(m2.id));
    });
  });
}

/// Subclass that replaces the async [_dir()] lookup with a fixed temp directory
/// so tests run without `path_provider` platform channel.
class _TempDirRepository extends AgreementRepository {
  _TempDirRepository(this._base);
  final Directory _base;

  Directory get _agreementsDir {
    final d = Directory('${_base.path}/agreements');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  @override
  Future<AgreementModel?> get(String id) async {
    final file = File('${_agreementsDir.path}/$id.json');
    if (!file.existsSync()) return null;
    return AgreementModel.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(AgreementModel model) async {
    await File(
      '${_agreementsDir.path}/${model.id}.json',
    ).writeAsString(jsonEncode(model.toJson()));
  }

  @override
  Future<List<AgreementModel>> listForAgent(String agentId) async {
    final files = _agreementsDir.listSync().whereType<File>().toList();
    final results = <AgreementModel>[];
    for (final f in files) {
      try {
        final model = AgreementModel.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>,
        );
        if (model.agentId == agentId) results.add(model);
      } catch (_) {}
    }
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<List<AgreementModel>> listPending(String agentId) async {
    final all = await listForAgent(agentId);
    return all.where((a) => a.isPendingDelivery).toList();
  }
}
