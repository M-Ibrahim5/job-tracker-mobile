import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/device_timezone.dart';
import '../../../domain/enums/enums.dart';
import '../../auth/application/biometric_controller.dart';

/// Change-password request (state = result of the latest attempt).
class ChangePasswordController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Changes the password; read [state] for the outcome.
  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      await ref.read(biometricActionsProvider).passwordChanged(newPassword);
    });
  }
}

/// Provider for [ChangePasswordController].
final changePasswordControllerProvider =
    AutoDisposeAsyncNotifierProvider<ChangePasswordController, void>(
      ChangePasswordController.new,
    );

/// Export and delete-all actions of the Data section.
class DataActions {
  /// Creates the actions bound to [_ref].
  DataActions(this._ref);

  final Ref _ref;

  /// Downloads the export and opens the share sheet.
  Future<void> export(ExportFormat format) async {
    final timezone = await _ref.read(deviceTimezoneProvider)();
    final bytes = await _ref
        .read(dataRepositoryProvider)
        .export(format, timezone: timezone);
    if (bytes.isEmpty) throw const StorageFailure('Empty export');
    final stamp = DateTime.now().toIso8601String().split('T').first;
    await _ref
        .read(fileSharerProvider)
        .shareBytes(bytes, 'jobtrail-export-$stamp.${format.name}');
  }

  /// Deletes all server data and tells data providers to reload.
  Future<void> deleteAll() async {
    await _ref.read(dataRepositoryProvider).deleteAllData();
    _ref.read(dataRevisionProvider.notifier).state++;
  }
}

/// Provider for [DataActions].
final dataActionsProvider = Provider<DataActions>(DataActions.new);
