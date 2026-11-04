import '../constants/app_constants.dart';
import '../errors/failures.dart';

/// Maps any error to text safe to show the user.
String failureMessage(Object error) {
  return switch (error) {
    NetworkFailure() => AppStrings.errNetwork,
    UnauthorizedFailure() => AppStrings.errSessionExpired,
    ApiFailure(code: ApiCodes.invalidCredentials) =>
      AppStrings.errInvalidCredentials,
    ApiFailure(code: ApiCodes.emailTaken) => AppStrings.errEmailTaken,
    ApiFailure(code: ApiCodes.interviewConflict) =>
      AppStrings.errInterviewConflict,
    ApiFailure(code: ApiCodes.rateLimited) => AppStrings.errRateLimited,
    ApiFailure(code: ApiCodes.notFound) => AppStrings.errNotFound,
    ApiFailure(code: ApiCodes.internal) => AppStrings.errGeneric,
    ApiFailure(:final message) when message.isNotEmpty => message,
    StorageFailure() => AppStrings.errStorage,
    _ => AppStrings.errGeneric,
  };
}
