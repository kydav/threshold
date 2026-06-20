import 'package:flutter/material.dart';

const List<String> kAllUsStates = [
  'Alabama',
  'Alaska',
  'Arizona',
  'Arkansas',
  'California',
  'Colorado',
  'Connecticut',
  'Delaware',
  'Florida',
  'Georgia',
  'Hawaii',
  'Idaho',
  'Illinois',
  'Indiana',
  'Iowa',
  'Kansas',
  'Kentucky',
  'Louisiana',
  'Maine',
  'Maryland',
  'Massachusetts',
  'Michigan',
  'Minnesota',
  'Mississippi',
  'Missouri',
  'Montana',
  'Nebraska',
  'Nevada',
  'New Hampshire',
  'New Jersey',
  'New Mexico',
  'New York',
  'North Carolina',
  'North Dakota',
  'Ohio',
  'Oklahoma',
  'Oregon',
  'Pennsylvania',
  'Rhode Island',
  'South Carolina',
  'South Dakota',
  'Tennessee',
  'Texas',
  'Utah',
  'Vermont',
  'Virginia',
  'Washington',
  'West Virginia',
  'Wisconsin',
  'Wyoming',
];

class BrokerageStep extends StatelessWidget {
  const BrokerageStep({
    required this.brokerageNameCtrl,
    required this.brokerageAddressCtrl,
    required this.brokerageCityStateZipCtrl,
    required this.agentPhoneCtrl,
    required this.state,
    required this.isMultiPersonFirm,
    required this.isBuyerAgency,
    required this.stateCallback,
    required this.multiPersonFirmCallback,
    required this.buyerAgencyCallback,
    required this.agentLicenseCtrl,
    required this.brokerageLicenseCtrl,
    required this.managingBrokerNameCtrl,
    required this.managingBrokerPhoneCtrl,
    required this.managingBrokerEmailCtrl,
    super.key,
  });

  final TextEditingController brokerageNameCtrl;
  final TextEditingController brokerageAddressCtrl;
  final TextEditingController brokerageCityStateZipCtrl;
  final TextEditingController agentPhoneCtrl;
  final String? state;
  final bool isMultiPersonFirm;
  final bool isBuyerAgency;
  final ValueChanged<String> stateCallback;
  final ValueChanged<bool> multiPersonFirmCallback;
  final ValueChanged<bool> buyerAgencyCallback;
  final TextEditingController agentLicenseCtrl;
  final TextEditingController brokerageLicenseCtrl;
  final TextEditingController managingBrokerNameCtrl;
  final TextEditingController managingBrokerPhoneCtrl;
  final TextEditingController managingBrokerEmailCtrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Brokerage details',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Used to pre-fill forms at every showing.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: brokerageNameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Brokerage name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: brokerageAddressCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Brokerage street address (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: brokerageCityStateZipCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'City, State, Zip (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: agentPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Your phone number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: state,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Select your state'),
            items:
                kAllUsStates
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
            onChanged: (v) {
              if (v == null) return;
              stateCallback(v);
            },
          ),
          if (state == 'Colorado') ...[
            const SizedBox(height: 20),
            Text('Firm type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _ChoiceCard(
              label: 'Multiple-person firm',
              subtitle:
                  'Section 2.1 — you are a designated broker within the firm',
              selected: isMultiPersonFirm,
              onTap: () => multiPersonFirmCallback(true),
            ),
            const SizedBox(height: 8),
            _ChoiceCard(
              label: 'One-person firm',
              subtitle: 'Section 2.2 — you are the sole licensed person',
              selected: !isMultiPersonFirm,
              onTap: () => multiPersonFirmCallback(false),
            ),
            const SizedBox(height: 20),
            Text(
              'Brokerage relationship',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'How you typically represent buyers. Used on every form — can be changed in settings.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _ChoiceCard(
              label: 'Buyer Agency',
              subtitle: 'You represent the buyer — most common for showings',
              selected: isBuyerAgency,
              onTap: () => buyerAgencyCallback(true),
            ),
            const SizedBox(height: 8),
            _ChoiceCard(
              label: 'Transaction-Brokerage',
              subtitle:
                  'You assist the transaction without representing either party',
              selected: !isBuyerAgency,
              onTap: () => buyerAgencyCallback(false),
            ),
          ],
          if (state == 'Oklahoma') ...[
            const SizedBox(height: 24),
            Text(
              'Oklahoma license info',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Pre-filled on every OREC form',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: agentLicenseCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Associate broker license number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: brokerageLicenseCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Brokerage license number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Managing broker',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: managingBrokerNameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Managing broker name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: managingBrokerPhoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Managing broker office telephone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: managingBrokerEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Managing broker email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? cs.primary : cs.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
