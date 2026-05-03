import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

abstract class HomeRepository {
  Future<List<Event>> searchEvents(String query);
  Stream<Photo> streamEventImages(String eventId, String email, bool alwaysPublicImages);
}
