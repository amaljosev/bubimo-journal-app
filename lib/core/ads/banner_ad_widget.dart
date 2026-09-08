// lib/core/ads/banner_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../di/injection.dart';
import 'ad_unit_ids.dart';
import 'ads_preference_service.dart';

/// A self-contained, reusable banner ad slot.
///
/// Renders nothing ([SizedBox.shrink]) whenever there's no ad to show:
/// before the first ad has loaded, if a load fails, or whenever
/// [AdsPreferenceService.adsEnabled] is off (e.g. once "remove ads"
/// ships). Callers never check any of that themselves — just place a
/// [BannerAdWidget] wherever a banner slot belongs.
///
/// Uses an anchored *adaptive* banner (sized to the caller's available
/// width via [AdSize.getLargeAnchoredAdaptiveBannerAdSize]) rather than
/// a fixed [AdSize.banner] — this is Google's current recommendation:
/// better fill rate, and a height that actually matches the device
/// instead of a fixed 320x50 letterboxed inside a wider screen.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  final ValueNotifier<bool> _adsEnabled =
      getIt<AdsPreferenceService>().adsEnabled;

  BannerAd? _bannerAd;
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();
    _adsEnabled.addListener(_onAdsPreferenceChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is safe to read here (unlike initState) — needed to
    // size the adaptive banner to the actual available width.
    if (_adsEnabled.value) {
      _loadAd();
    }
  }

  void _onAdsPreferenceChanged() {
    if (_adsEnabled.value) {
      _loadAd();
    } else {
      _disposeAd();
    }
  }

  Future<void> _loadAd() async {
    // Already showing one, or a load is already in flight — don't
    // stack duplicate requests from rapid rebuilds.
    if (_bannerAd != null || _isLoadingAd) return;
    _isLoadingAd = true;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);

    // The preference may have flipped, or this widget may have been
    // disposed, while we were awaiting the size lookup above.
    if (!mounted || !_adsEnabled.value) {
      _isLoadingAd = false;
      return;
    }

    final ad = BannerAd(
      adUnitId: AdUnitIds.banner,
      size: size ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          _isLoadingAd = false;
          if (!mounted || !_adsEnabled.value) {
            loadedAd.dispose();
            return;
          }
          setState(() => _bannerAd = loadedAd as BannerAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          // Sensible failure behavior: log and stay hidden. No retry
          // loop — the next rebuild (tab switch, preference change,
          // navigation back to this screen) naturally tries again. A
          // banner slot that silently disappears is far less
          // disruptive than one that hammers the ad network on a
          // timer.
          debugPrint('BannerAdWidget: failed to load ad: $error');
          failedAd.dispose();
          _isLoadingAd = false;
        },
      ),
    );

    await ad.load();
  }

  void _disposeAd() {
    final ad = _bannerAd;
    _bannerAd = null;
    ad?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _adsEnabled.removeListener(_onAdsPreferenceChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();

    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}