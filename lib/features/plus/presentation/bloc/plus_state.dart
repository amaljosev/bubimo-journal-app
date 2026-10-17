part of 'plus_bloc.dart';

enum PlusLoadStatus { initial, loaded }

enum PlusProductsStatus { idle, loading, loaded, failure }

enum PlusPurchaseStatus { idle, purchasing, pending, restoring }

enum PlusFeedbackType { success, info, error }

/// A one-shot message for the UI to show (SnackBar). [id] changes for
/// every new message so the same text twice in a row still re-triggers
/// the listener.
class PlusFeedback extends Equatable {
  final int id;
  final PlusFeedbackType type;
  final String message;

  const PlusFeedback({
    required this.id,
    required this.type,
    required this.message,
  });

  @override
  List<Object?> get props => [id, type, message];
}

class PlusState extends Equatable {
  final PlusLoadStatus loadStatus;
  final PlusStatus plus;

  final PlusProductsStatus productsStatus;
  final List<PlusProduct> products;
  final String? productsError;

  final PlusPurchaseStatus purchaseStatus;
  final PlusFeedback? feedback;

  const PlusState({
    this.loadStatus = PlusLoadStatus.initial,
    this.plus = const PlusStatus.free(),
    this.productsStatus = PlusProductsStatus.idle,
    this.products = const [],
    this.productsError,
    this.purchaseStatus = PlusPurchaseStatus.idle,
    this.feedback,
  });

  bool get isPlus => plus.isPlus;

  /// True while a purchase sheet is open or a restore is running —
  /// the paywall disables its buttons. A merely *pending* payment is
  /// not busy, so a stuck pending state can never lock the screen.
  bool get isBusy =>
      purchaseStatus == PlusPurchaseStatus.purchasing ||
      purchaseStatus == PlusPurchaseStatus.restoring;

  PlusState copyWith({
    PlusLoadStatus? loadStatus,
    PlusStatus? plus,
    PlusProductsStatus? productsStatus,
    List<PlusProduct>? products,
    String? productsError,
    bool clearProductsError = false,
    PlusPurchaseStatus? purchaseStatus,
    PlusFeedback? feedback,
    bool clearFeedback = false,
  }) {
    return PlusState(
      loadStatus: loadStatus ?? this.loadStatus,
      plus: plus ?? this.plus,
      productsStatus: productsStatus ?? this.productsStatus,
      products: products ?? this.products,
      productsError: clearProductsError
          ? null
          : (productsError ?? this.productsError),
      purchaseStatus: purchaseStatus ?? this.purchaseStatus,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    plus,
    productsStatus,
    products,
    productsError,
    purchaseStatus,
    feedback,
  ];
}
