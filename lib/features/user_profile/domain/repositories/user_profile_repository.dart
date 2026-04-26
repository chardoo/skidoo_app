abstract class UserProfileRepository {
  Future<String> getName();
  Future<String> getEmail();
  Future<Map<String, dynamic>> getFullProfile();
  Future<void> updateLocalProfile(Map<String, dynamic> data);
  Future<void> logout();
}
