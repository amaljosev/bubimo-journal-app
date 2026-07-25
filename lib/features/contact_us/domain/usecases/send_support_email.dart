// lib/features/contact_us/domain/usecases/send_support_email.dart

import 'package:fpdart/fpdart.dart';

import 'package:bubimo/core/error/failures.dart';
import 'package:bubimo/features/contact_us/domain/contact_reason.dart';
import 'package:bubimo/features/contact_us/domain/repositories/contact_repository.dart';

/// Launches the device mail client for a given [ContactReason].
///
/// Thin wrapper over [ContactRepository.sendSupportEmail] — kept as
/// its own use case (rather than calling the repository directly from
/// the widget) to match the rest of the app's domain-layer pattern.
class SendSupportEmail {
  final ContactRepository repository;

  const SendSupportEmail(this.repository);

  Future<Either<Failure, Unit>> call(ContactReason reason) {
    return repository.sendSupportEmail(reason);
  }
}