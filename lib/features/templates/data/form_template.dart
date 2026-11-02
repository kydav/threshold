import 'dart:ui';

/// Who supplies a field's value.
enum FieldFiller {
  /// The agent's own details, entered once when the template is set up.
  agentOnce,

  /// Terms the agent sets for each buyer (end date, fee, area).
  agentPerDeal,

  /// Anything the buyer writes, checks, initials or signs.
  buyer,

  /// The agent's or broker's acceptance signature and its date.
  agentSign;

  static FieldFiller parse(String s) => switch (s) {
    'agent_once' => agentOnce,
    'agent_per_deal' => agentPerDeal,
    'agent_sign' => agentSign,
    _ => buyer,
  };

  String get wire => switch (this) {
    agentOnce => 'agent_once',
    agentPerDeal => 'agent_per_deal',
    buyer => 'buyer',
    agentSign => 'agent_sign',
  };

  String get label => switch (this) {
    agentOnce => 'You, once',
    agentPerDeal => 'You, each deal',
    buyer => 'Buyer',
    agentSign => 'Your signature',
  };
}

enum FieldKind {
  text,
  date,
  number,
  currency,
  percent,
  checkbox,
  signature,
  initials;

  static FieldKind parse(String s) =>
      FieldKind.values.firstWhere((k) => k.name == s, orElse: () => text);

  bool get isInk => this == signature || this == initials;
}

/// What a field is, so the app can fill it (or not ask) instead of the agent
/// typing it: names from the buyers already entered, agent details from the
/// profile, dates from today.
enum FieldRole {
  buyerNames,
  buyer1Name,
  buyer2Name,
  buyerEmail,
  buyerAddressPhone,
  brokerageName,
  agentName,
  agentLicense,
  endDate,
  startDate,
  feeAmount,
  feePercent,
  protectionMonths,
  area,
  propertyAddress,
  excludedProperties,
  signature,
  initials,
  signDate,
  other;

  String get wire => switch (this) {
    buyerNames => 'buyer_names',
    buyer1Name => 'buyer1_name',
    buyer2Name => 'buyer2_name',
    buyerEmail => 'buyer_email',
    buyerAddressPhone => 'buyer_address_phone',
    brokerageName => 'brokerage_name',
    agentName => 'agent_name',
    agentLicense => 'agent_license',
    endDate => 'end_date',
    startDate => 'start_date',
    feeAmount => 'fee_amount',
    feePercent => 'fee_percent',
    protectionMonths => 'protection_months',
    area => 'area',
    propertyAddress => 'property_address',
    excludedProperties => 'excluded_properties',
    signature => 'signature',
    initials => 'initials',
    signDate => 'sign_date',
    other => 'other',
  };

  static FieldRole parse(String? s) =>
      FieldRole.values.where((r) => r.wire == s).firstOrNull ?? other;

  /// Filled from the buyers the agent entered: never asked for.
  bool get isBuyerName =>
      this == buyerNames || this == buyer1Name || this == buyer2Name;

  /// Templates mapped before roles existed: a best guess from id and label.
  static FieldRole infer(String id, String label, FieldKind kind) {
    final t = '${id.toLowerCase()} ${label.toLowerCase()}';
    if (kind == FieldKind.signature) return signature;
    if (kind == FieldKind.initials) return initials;
    if (t.contains('buyer') && t.contains('name')) {
      if (t.contains('name(s)') || t.contains('names')) return buyerNames;
      return RegExp(r'(_2\b|second|buyer 2)').hasMatch(t)
          ? buyer2Name
          : buyer1Name;
    }
    if (t.contains('count')) return area;
    if (t.contains('exclu')) return excludedProperties;
    if (t.contains('propert') && t.contains('address')) return propertyAddress;
    if (t.contains('percent') || t.contains('%')) return feePercent;
    if (t.contains('protection')) return protectionMonths;
    return other;
  }
}

/// One place on the form where someone writes, checks, initials or signs.
class TemplateField {
  TemplateField({
    required this.id,
    required this.page,
    required this.section,
    required this.label,
    required this.kind,
    required this.filledBy,
    required this.choiceGroup,
    required this.box,
    required this.currentlyFilled,
    FieldRole? role,
    this.groupTitle = '',
    this.dependsOn = '',
    this.continues = '',
    this.defaultChecked = false,
  }) : role = role ?? FieldRole.infer(id, label, kind);

  final String id;

  /// 1-based page number.
  final int page;
  final String section;
  String label;
  FieldKind kind;
  FieldFiller filledBy;

  /// Shared by the options of a "check one" group; empty otherwise.
  final String choiceGroup;

  /// Where the value goes, in pixels of the stored page image.
  Rect box;

  /// The source copy already had something written here (cleared on save).
  final bool currentlyFilled;

  final FieldRole role;

  /// The question this field is grouped under on the fill-out screen.
  final String groupTitle;

  /// Id of the checkbox option this only applies to (shown once checked).
  final String dependsOn;

  /// Id of the blank this line continues (one answer wrapped over lines).
  final String continues;

  /// Pre-selected: the form's stated default, or the usual choice.
  final bool defaultChecked;

  factory TemplateField.fromMap(Map<String, dynamic> m) {
    final b = (m['box'] as List).map((v) => (v as num).toDouble()).toList();
    return TemplateField(
      id: m['id'] as String,
      page: (m['page'] as num).toInt(),
      section: m['section'] as String? ?? '',
      label: m['label'] as String? ?? '',
      kind: FieldKind.parse(m['kind'] as String? ?? 'text'),
      filledBy: FieldFiller.parse(m['filled_by'] as String? ?? 'buyer'),
      choiceGroup: m['choice_group'] as String? ?? '',
      box: b.length == 4 ? Rect.fromLTRB(b[0], b[1], b[2], b[3]) : Rect.zero,
      currentlyFilled: m['currently_filled'] as bool? ?? false,
      role: m['role'] == null ? null : FieldRole.parse(m['role'] as String?),
      groupTitle: m['group_title'] as String? ?? '',
      dependsOn: m['depends_on'] as String? ?? '',
      continues: m['continues'] as String? ?? '',
      defaultChecked: m['default_checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'page': page,
    'section': section,
    'label': label,
    'kind': kind.name,
    'filled_by': filledBy.wire,
    'choice_group': choiceGroup,
    'box': [box.left, box.top, box.right, box.bottom],
    'currently_filled': currentlyFilled,
    'role': role.wire,
    'group_title': groupTitle,
    'depends_on': dependsOn,
    'continues': continues,
    'default_checked': defaultChecked,
  };
}

/// A stored page: its image file (relative to the template's folder) and size.
class TemplatePage {
  const TemplatePage({
    required this.file,
    required this.width,
    required this.height,
  });

  final String file;
  final int width;
  final int height;

  Size get size => Size(width.toDouble(), height.toDouble());

  factory TemplatePage.fromMap(Map<String, dynamic> m) => TemplatePage(
    file: m['file'] as String,
    width: (m['width'] as num).toInt(),
    height: (m['height'] as num).toInt(),
  );

  Map<String, dynamic> toMap() => {
    'file': file,
    'width': width,
    'height': height,
  };
}

/// An agent's own form, turned into a reusable, fillable template.
class FormTemplate {
  FormTemplate({
    required this.id,
    required this.title,
    required this.formId,
    required this.pages,
    required this.fields,
    required this.createdAt,
    Map<String, String>? agentValues,
    Map<String, Object>? dealDefaults,
  }) : agentValues = agentValues ?? {},
       dealDefaults = dealDefaults ?? {};

  final String id;
  String title;
  final String formId;
  final List<TemplatePage> pages;
  final List<TemplateField> fields;
  final DateTime createdAt;

  /// Values for the agent-once fields, keyed by field id.
  final Map<String, String> agentValues;

  /// Per-deal answers to start each deal with (the agent's usual fee,
  /// protection period, mediation choice...), set at import and updated to
  /// the last deal's answers. Strings, or bools for checkboxes.
  final Map<String, Object> dealDefaults;

  Iterable<TemplateField> fieldsBy(FieldFiller f) =>
      fields.where((x) => x.filledBy == f);

  factory FormTemplate.fromMap(Map<String, dynamic> m) => FormTemplate(
    id: m['id'] as String,
    title: m['title'] as String? ?? 'My form',
    formId: m['formId'] as String? ?? '',
    pages: [
      for (final p in m['pages'] as List)
        TemplatePage.fromMap(p as Map<String, dynamic>),
    ],
    fields: [
      for (final f in m['fields'] as List)
        TemplateField.fromMap(f as Map<String, dynamic>),
    ],
    createdAt: DateTime.parse(m['createdAt'] as String),
    agentValues: Map<String, String>.from(m['agentValues'] as Map? ?? const {}),
    dealDefaults: {
      for (final e in (m['dealDefaults'] as Map? ?? const {}).entries)
        if (e.value is String || e.value is bool) '${e.key}': e.value as Object,
    },
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'formId': formId,
    'pages': [for (final p in pages) p.toMap()],
    'fields': [for (final f in fields) f.toMap()],
    'createdAt': createdAt.toIso8601String(),
    'agentValues': agentValues,
    'dealDefaults': dealDefaults,
  };
}
