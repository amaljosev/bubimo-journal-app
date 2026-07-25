// lib/features/contact_us/data/repositories/contact_repository_impl.dart

import 'package:fpdart/fpdart.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bubimo/core/constants/app_constants.dart';
import 'package:bubimo/core/error/failures.dart';
import 'package:bubimo/features/contact_us/domain/contact_reason.dart';
import 'package:bubimo/features/contact_us/domain/repositories/contact_repository.dart';

class ContactRepositoryImpl implements ContactRepository {
  const ContactRepositoryImpl();

  @override
  Future<Either<Failure, Unit>> sendSupportEmail(ContactReason reason) async {
    final encodedSubject = Uri.encodeComponent(reason.emailSubject);
    final emailUri = Uri.parse(
      'mailto:${AppConstants.supportMail}?subject=$encodedSubject',
    );

    try {
      final launched = await launchUrl(emailUri);
      if (!launched) {
        return const Left(ContactFailure('Could not open mail app'));
      }
      return const Right(unit);
    } catch (_) {
      return const Left(ContactFailure('Could not open mail app'));
    }
  }
}