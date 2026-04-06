abstract class CartRepository {
  Future<Map<String, dynamic>> initiatePayment(String email, String amount);
  Future<Map<String, dynamic>> completePayment(Map<String, dynamic> payload);
  Future<void> downloadImage(String url);

  /// POST /client/payments/free — save images to gallery without payment.
  /// [items] is a list of maps with keys: pictureId, clientId, userId.
  Future<void> saveImagesFree(List<Map<String, String>> items);
}
