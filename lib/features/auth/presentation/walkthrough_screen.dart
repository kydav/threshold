import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

/// "How Threshold works": four swipeable steps with real screenshots.
/// Shown once right after setup ([firstRun]), and any time from Profile.
class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({this.firstRun = false, super.key});

  /// Right after sign-up: leaving goes to the dashboard instead of back.
  final bool firstRun;

  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _Step {
  const _Step(this.label, this.title, this.body, this.image, {this.badge});
  final String label;
  final String title;
  final String body;
  final String image;

  /// A second screenshot laid over the first (the "Signed" card).
  final String? badge;
}

const _dir = 'assets/images/walkthrough';

const _steps = [
  _Step(
    'Step 1 · Once',
    'Add your buyer agreement once',
    'Scan the paper copy or upload the PDF. Threshold finds every blank, '
        "checkbox and signature line, so it's ready for every deal after.",
    '$_dir/forms.jpg',
  ),
  _Step(
    'Step 2 · At the showing',
    'Fill it in under a minute',
    'Your name and brokerage are already filled in. Add the buyers, pick '
        'the end date and where you represent them.',
    '$_dir/fill.jpg',
  ),
  _Step(
    'Step 3 · The buyer',
    'Hand them the phone',
    'Buyers read a plain-English overview above the real agreement, then '
        'initial and sign right on the screen.',
    '$_dir/review.jpg',
  ),
  _Step(
    'Step 4 · Done',
    'Signed and sent',
    'You sign last, and everyone gets the signed PDF by email. No signal at '
        "the house? It sends once you're back online.",
    '$_dir/sign.jpg',
    badge: '$_dir/done.jpg',
  ),
];

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _page == _steps.length - 1;

  void _leave() {
    if (widget.firstRun || !context.canPop()) {
      context.go('/home');
    } else {
      context.pop();
    }
  }

  /// The last step's button: start the first agreement. Agents in states
  /// without a built-in form are sent on to add their own.
  void _start() {
    final router = GoRouter.of(context);
    if (widget.firstRun || !context.canPop()) {
      router.go('/home');
    } else {
      router.pop();
    }
    router.push('/agreements/new');
  }

  void _next() {
    if (_last) return _start();
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final builtIn = kSupportedStates.contains(
      ref.watch(userProfileProvider)?.state,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Visibility(
                  visible: !_last,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _leave,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _StepView(step: _steps[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Semantics(
                    label: 'Step ${_page + 1} of ${_steps.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _steps.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  i == _page ? cs.primary : cs.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(
                      !_last
                          ? 'Next'
                          : builtIn
                          ? 'Start an agreement'
                          : 'Add your first form',
                    ),
                  ),
                  if (_last) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _leave,
                      child: const Text('Maybe later'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.16),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              // Tall screenshots fade out at the bottom of the stage.
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback:
                    (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.black, Colors.transparent],
                      stops: [0, 0.86, 1],
                    ).createShader(r),
                child: LayoutBuilder(
                  builder:
                      (context, box) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 24,
                            left: box.maxWidth * 0.11,
                            right: box.maxWidth * 0.11,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: shadow,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  step.image,
                                  fit: BoxFit.fitWidth,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                          if (step.badge != null)
                            Positioned(
                              right: box.maxWidth * 0.06,
                              bottom: box.maxHeight * 0.16,
                              width: box.maxWidth * 0.62,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: shadow,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    step.badge!,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            step.label.toUpperCase(),
            style: text.labelMedium?.copyWith(
              color: cs.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.title,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
