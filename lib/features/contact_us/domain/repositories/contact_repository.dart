// lib/features/contact_us/domain/repositories/contact_repository.dart

import 'package:fpdart/fpdart.dart';

import 'package:bubimo/core/error/failures.dart';
import 'package:bubimo/features/contact_us/domain/contact_reason.dart';

/// Abstraction over "contact support" actions. Kept separate from
/// [ContactReason] so the domain layer has no dependency on
/// url_launcher or any other concrete email/mail-client package.
abstract class ContactRepository {
  /// Opens the device's mail client with a prefilled subject line
  /// derived from [reason], addressed to the app's support email.
  ///
  /// Returns [Left] with a [Failure] if no mail client could be
  /// launched (e.g. no email app installed).
  Future<Either<Failure, Unit>> sendSupportEmail(ContactReason reason);
}