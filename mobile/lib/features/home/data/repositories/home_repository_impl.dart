import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:jperg_app/features/home/domain/repositories/home_repository.dart';
import 'package:jperg_app/models/event/Event.dart';
import 'package:jperg_app/models/photos/Photo.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;
  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      return await _remoteDataSource.searchEvents(query);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error searching events: $e');
    }
  }

  @override
  Stream<Photo> streamEventImages(String eventId, String email, bool alwaysPublicImages) =>
      _remoteDataSource.streamEventImages(eventId, email, alwaysPublicImages);
}
