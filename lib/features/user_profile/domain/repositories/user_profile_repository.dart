abstract class UserProfileRepository {
  Future<String> getName();
  Future<String> getEmail();
  Future<void> logout();
}
