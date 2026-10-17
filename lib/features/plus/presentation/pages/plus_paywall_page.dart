// lib/features/plus/presentation/pages/plus_paywall_page.dart

import 'package:bubimo/core/constants/app_constants.dart';
import 'package:bubimo/core/utils/url_launcher_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/plus_feature.dart';
import '../../domain/entities/plus_plan.dart';
import '../../domain/entities/plus_product.dart';
import '../../domain/entities/plus_status.dart';
import '../bloc/plus_bloc.dart';
import '../widgets/plus_benefits_list.dart';
import '../widgets/plus_plan_card.dart';

/// The Plus paywall. Also the "you're a member" screen when opened by
/// someone who already has Plus (from Settings).
///
/// Expects [PlusBloc] in context (provided at the app root).
/// Pops `true` when a free user becomes a Plus member here, which is
/// what `PlusGate.require` waits for.
class PlusPaywallPage extends StatefulWidget {
  /// The feature the user tapped to get here, if any — only changes
  /// the headline.
  final PlusFeature? feature;

  const PlusPaywallPage({super.key, this.feature});

  @override
  State<PlusPaywallPage> createState() => _PlusPaywallPageState();
}

class _PlusPaywallPageState extends State<PlusPaywallPage> {
  static const String _manageSubscriptionUrl =
      'https://play.google.com/store/account/subscriptions';

  PlusPlan _selected = PlusPlan.yearly;
  late final bool _openedAsFree;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<PlusBloc>();
    _openedAsFree = !bloc.state.isPlus;
    bloc.add(const PlusProductsRequested());
  }

  PlusProduct? _productFor(List<PlusProduct> products, PlusPlan plan) {
    for (final p in products) {
      if (p.plan == plan) return p;
    }
    return null;
  }

  /// "Save 33%" for yearly vs paying monthly for 12 months; null when
  /// the saving is too small to be worth advertising.
  int? _yearlySavingsPercent(List<PlusProduct> products) {
    final monthly = _productFor(products, PlusPlan.monthly);
    final yearly = _productFor(products, PlusPlan.yearly);
    if (monthly == null || yearly == null || monthly.priceMicros == 0) {
      return null;
    }
    final percent =
        ((1 - yearly.priceMicros / (monthly.priceMicros * 12)) * 100).round();
    return percent >= 5 ? percent : null;
  }

  String _planTitle(PlusPlan plan) => switch (plan) {
    PlusPlan.monthly => 'Monthly',
    PlusPlan.yearly => 'Yearly',
    PlusPlan.lifetime => 'Lifetime',
  };

  String _priceLine(PlusProduct p) => switch (p.plan) {
    PlusPlan.monthly => '${p.formattedPrice} / month',
    PlusPlan.yearly => '${p.formattedPrice} / year',
    PlusPlan.lifetime => '${p.formattedPrice} one-time',
  };

  String _trialPhrase(PlusProduct p) {
    final label = p.freeTrialLabel ?? '';
    return label.isEmpty ? 'free trial' : '$label free trial';
  }

  String _ctaLabel(PlusProduct p) {
    if (p.hasFreeTrial) return 'Start ${_trialPhrase(p)}';
    return switch (p.plan) {
      PlusPlan.lifetime => 'Buy Lifetime · ${p.formattedPrice}',
      PlusPlan.monthly => 'Subscribe · ${p.formattedPrice} / month',
      PlusPlan.yearly => 'Subscribe · ${p.formattedPrice} / year',
    };
  }

  String _finePrint(PlusProduct p) {
    if (p.plan == PlusPlan.lifetime) {
      return 'One-time payment. No renewals — yours for good.';
    }
    final period = p.plan == PlusPlan.monthly ? 'month' : 'year';
    if (p.hasFreeTrial) {
      return 'Free for the first ${p.freeTrialLabel?.isNotEmpty == true ? p.freeTrialLabel!.replaceAll('-', ' ') : 'trial period'}, '
          'then ${p.formattedPrice} / $period. Cancel anytime in Google Play '
          'before the trial ends and you won\'t be charged.';
    }
    return 'Renews automatically at ${p.formattedPrice} / $period until you '
        'cancel in Google Play.';
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PlusBloc, PlusState>(
          listenWhen: (previous, current) =>
              current.feedback != null &&
              current.feedback?.id != previous.feedback?.id,
          listener: (context, state) {
            final feedback = state.feedback!;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(feedback.message)));
          },
        ),
        BlocListener<PlusBloc, PlusState>(
          listenWhen: (previous, current) =>
              _openedAsFree && !previous.isPlus && current.isPlus,
          listener: (context, state) {
            if (context.canPop()) context.pop(true);
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(false),
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<PlusBloc, PlusState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _Header(feature: widget.feature, isPlus: state.isPlus),
                  const SizedBox(height: 20),
                  const PlusBenefitsList(),
                  const SizedBox(height: 20),
                  if (state.isPlus)
                    _MemberCard(
                      tier: state.plus.tier,
                      onManage: () => UrlLauncherHelper.launchUrlString(
                        context,
                        _manageSubscriptionUrl,
                        LaunchMode.externalApplication,
                      ),
                    )
                  else
                    _buildPurchaseSection(context, state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseSection(BuildContext context, PlusState state) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    switch (state.productsStatus) {
      case PlusProductsStatus.idle:
      case PlusProductsStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        );
      case PlusProductsStatus.failure:
        return Column(
          children: [
            Text(
              state.productsError ?? 'Could not load plans.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  context.read<PlusBloc>().add(const PlusProductsRequested()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        );
      case PlusProductsStatus.loaded:
        break;
    }

    final products = state.products;
    // If the selected plan isn't offered, fall back to the first one.
    final selected =
        _productFor(products, _selected) ?? products.first;
    final savings = _yearlySavingsPercent(products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final plan in const [
          PlusPlan.yearly,
          PlusPlan.monthly,
          PlusPlan.lifetime,
        ])
          if (_productFor(products, plan) case final product?) ...[
            PlusPlanCard(
              title: _planTitle(plan),
              priceLine: _priceLine(product),
              badge: plan == PlusPlan.yearly
                  ? (savings != null ? 'Save $savings%' : 'Best value')
                  : null,
              trialNote:
                  product.hasFreeTrial ? _trialPhrase(product) : null,
              isSelected: selected.plan == plan,
              isEnabled: !state.isBusy,
              onTap: () => setState(() => _selected = plan),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 6),
        FilledButton(
          onPressed: state.isBusy
              ? null
              : () => context.read<PlusBloc>().add(
                  PlusPurchaseRequested(selected.plan),
                ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: state.purchaseStatus == PlusPurchaseStatus.purchasing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_ctaLabel(selected)),
        ),
        const SizedBox(height: 10),
        Text(
          _finePrint(selected),
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.isBusy
              ? null
              : () => context.read<PlusBloc>().add(const PlusRestoreRequested()),
          child: state.purchaseStatus == PlusPurchaseStatus.restoring
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Restore purchases'),
        ),
        TextButton(
          onPressed: () => UrlLauncherHelper.launchUrlString(
            context,
            AppConstants.privacyPolicyUrl,
            LaunchMode.inAppWebView,
          ),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final PlusFeature? feature;
  final bool isPlus;

  const _Header({required this.feature, required this.isPlus});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final headline = isPlus
        ? 'Bubimo Plus'
        : (feature != null
              ? '${feature!.title} is a Plus feature'
              : 'Make your diary truly yours');
    final subline = isPlus
        ? 'Thank you for supporting Bubimo.'
        : (feature?.pitch ?? 'Unlock everything Bubimo has to offer.');

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            size: 38,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subline,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final PlusTier? tier;
  final VoidCallback onManage;

  const _MemberCard({required this.tier, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLifetime = tier == PlusTier.lifetime;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            'You\'re a Plus member',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            isLifetime
                ? 'Lifetime access — yours for good.'
                : 'Your subscription is active.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isLifetime) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onManage,
              child: const Text('Manage subscription'),
            ),
          ],
        ],
      ),
    );
  }
}
