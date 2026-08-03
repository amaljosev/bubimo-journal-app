// lib/features/app_lock/data/repositories/app_lock_repository_impl.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:fpdart/fpdart.dart';
import '../../domain/entities/lock_config.dart';
import '../../domain/entities/lock_failure.dart';
import '../../domain/entities/lock_type.dart';
import '../../domain/repositories/app_lock_repository.dart';
import '../datasources/biometric_data_source.dart';
import '../datasources/lock_local_data_source.dart';

class AppLockRepositoryImpl implements AppLockRepository {
  AppLockRepositoryImpl({
    required LockLocalDataSource localDataSource,
    required BiometricDataSource biometricDataSource,
  }) : _local = localDataSource,
       _biometric = biometricDataSource;

  final LockLocalDataSource _local;
  final BiometricDataSource _biometric;

  /// SHA-256 hex digest — PIN/answer are hashed here and only the hash
  /// ever reaches storage (see LockSettingsModel's doc comment) or is
  /// compared against on verify. No salt: a per-installation salt would
  /// need its own storage slot this schema doesn't have, and the
  /// threat model here is "don't leave the raw PIN sitting in the
  /// database file" rather than defending against an offline
  /// dictionary attack on a stolen hash — same tradeoff a 4-digit PIN
  /// implies either way.
  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  /// Logs the real platform/plugin error (e.g. the raw
  /// PlatformException/LocalAuthException local_auth throws) to the
  /// debug console only. Never returned to callers and never surfaced
  /// to the user — UI-facing text always comes from the LockFailure's
  /// own fixed, human-readable default message (see lock_failure.dart),
  /// regardless of what the underlying exception actually says.
  void _logBiometricError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[AppLock] $where failed: $error\n$stack');
    }
  }

  @override
  TaskEither<LockFailure, LockConfig> getLockConfig() {
    return TaskEither<LockFailure, LockConfig>.tryCatch(
      () async {
        final settings = await _local.getSettings();
        return LockConfig(
          lockType: settings.lockType,
          securityQuestion: settings.securityQuestion,
          biometricEnabled: settings.biometricEnabled,
        );
      },
      (error, stack) => StorageFailure('Failed to read lock settings: $error'),
    );
  }

  @override
  TaskEither<LockFailure, Unit> setLockType({
    required LockType type,
    String? pin,
    String? question,
    String? answer,
  }) {
    return TaskEither<LockFailure, Unit>.tryCatch(
      () async {
        final existing = await _local.getSettings();
        final updated = existing.copyWith(
          lockType: type,
          pinHash: type == LockType.pin && pin != null ? _hash(pin) : existing.pinHash,
          securityQuestion:
              type == LockType.securityQuestion ? question : existing.securityQuestion,
          securityAnswerHash: type == LockType.securityQuestion && answer != null
              ? _hash(answer.trim().toLowerCase())
              : existing.securityAnswerHash,
        );
        await _local.updateSettings(updated);
        return unit;
      },
      (error, stack) => StorageFailure('Failed to save lock settings: $error'),
    );
  }

  @override
  TaskEither<LockFailure, Unit> setBiometricEnabled(bool enabled) {
    return TaskEither<LockFailure, Unit>.tryCatch(
      () async {
        final existing = await _local.getSettings();
        await _local.updateSettings(existing.copyWith(biometricEnabled: enabled));
        return unit;
      },
      (error, stack) => StorageFailure('Failed to update biometric setting: $error'),
    );
  }

  @override
  TaskEither<LockFailure, bool> isBiometricAvailable() {
    return TaskEither<LockFailure, bool>.tryCatch(
      () => _biometric.isAvailable(),
      (error, stack) {
        _logBiometricError('isBiometricAvailable', error, stack);
        return const BiometricUnavailableFailure();
      },
    );
  }

  @override
  TaskEither<LockFailure, bool> authenticateWithBiometrics({
    required String reason,
  }) {
    return TaskEither<LockFailure, bool>.tryCatch(
      () => _biometric.authenticate(reason: reason),
      (error, stack) {
        _logBiometricError('authenticateWithBiometrics', error, stack);
        return const BiometricAuthFailure();
      },
    );
  }

  @override
  TaskEither<LockFailure, Unit> verifyPin(String pin) {
    return TaskEither<LockFailure, String?>.tryCatch(
      () async => (await _local.getSettings()).pinHash,
      (error, stack) => StorageFailure('Failed to read stored PIN: $error'),
    ).flatMap<Unit>((storedHash) {
      if (storedHash == null) {
        return TaskEither<LockFailure, Unit>.left(const NotConfiguredFailure());
      }
      if (storedHash == _hash(pin)) {
        return TaskEither<LockFailure, Unit>.right(unit);
      }
      return TaskEither<LockFailure, Unit>.left(const IncorrectPinFailure());
    });
  }

  @override
  TaskEither<LockFailure, Unit> verifySecurityAnswer(String answer) {
    return TaskEither<LockFailure, String?>.tryCatch(
      () async => (await _local.getSettings()).securityAnswerHash,
      (error, stack) =>
          StorageFailure('Failed to read stored security answer: $error'),
    ).flatMap<Unit>((storedHash) {
      if (storedHash == null) {
        return TaskEither<LockFailure, Unit>.left(const NotConfiguredFailure());
      }
      if (storedHash == _hash(answer.trim().toLowerCase())) {
        return TaskEither<LockFailure, Unit>.right(unit);
      }
      return TaskEither<LockFailure, Unit>.left(const IncorrectAnswerFailure());
    });
  }
}