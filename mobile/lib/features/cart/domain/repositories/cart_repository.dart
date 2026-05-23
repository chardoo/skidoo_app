abstract class CartRepository {
  Future<Map<String, dynamic>> initiatePayment(String email, String amount);
  Future<Map<String, dynamic>> completePayment(Map<String, dynamic> payload);
  Future<void> downloadImage(String url);

  /// POST /client/payments/free — save images to gallery without payment.
  /// [items] is a list of maps with keys: pictureId, clientId, userId.
  Future<void> saveImagesFree(List<Map<String, String>> items);

  /// POST /client/payments/initialize-images — start Paystack checkout for specific images.
  Future<Map<String, dynamic>> initializeImages({
    required String email,
    required String clientId,
    required List<String> pictureIds,
  });

  /// POST /client/payments/complete-images — confirm payment after Paystack redirect.
  /// [pictures] is a list of maps with keys: pictureId, userId (photographer).
  Future<Map<String, dynamic>> completeImages({
    required String referenceId,
    required String clientId,
    required List<Map<String, String>> pictures,
  });
}
