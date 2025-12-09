class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool success;

  ApiResponse.success(this.data)
      : success = true,
        error = null;

  ApiResponse.error(this.error)
      : success = false,
        data = null;
}