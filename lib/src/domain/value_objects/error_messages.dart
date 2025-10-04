String mapErrorMessage({int? statusCode, String? fallback}) {
  if (fallback != null && fallback.trim().isNotEmpty) {
    return fallback.trim();
  }

  switch (statusCode) {
    case 400:
      return 'Something went wrong with your request.';
    case 401:
      return 'You’re not logged in.';
    case 403:
      return 'You don’t have permission to do this.';
    case 404:
      return 'Oops! The page or data you’re looking for isn’t here.';
    case 408:
      return 'The connection took too long.';
    case 422:
      return 'Some of the information provided is invalid.';
    case 429:
      return 'You’re going too fast. Please wait a moment.';
    case 500:
      return 'Something broke on our side.';
    case 502:
      return 'The server had trouble responding.';
    case 503:
      return 'The service is temporarily down.';
    case 504:
      return 'Server took too long to respond.';
    default:
      return 'An unexpected error occurred. Please try again.';
  }
}
