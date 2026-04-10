/// A lightweight user record used in the share / DM-search flow.
/// Carries both the user's identity and their role so
/// [GetOrCreateDirectRoomUseCase] can be called directly.
class ShareableUser {
  final String id;
  final String name;
  final String email;
  final String? imageUrl;

  /// 'client' or 'photographer' — matches [ChatConfig] role constants.
  final String role;

  const ShareableUser({
    required this.id,
    required this.name,
    required this.email,
    this.imageUrl,
    required this.role,
  });
}
