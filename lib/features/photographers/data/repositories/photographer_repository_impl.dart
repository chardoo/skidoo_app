import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/photographers/data/datasources/photographer_remote_data_source.dart';
import 'package:skidoo_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotographerRepositoryImpl implements PhotographerRepository {
  final PhotographerRemoteDataSource _remoteDataSource;
  PhotographerRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<PhotographerModel>> getPhotographers() async {
    try {
      return await _remoteDataSource.getPhotographers();
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error loading photographers: $e');
    }
  }

  @override
  Future<List<PhotographerModel>> searchPhotographers(String query) async {
    try {
      return await _remoteDataSource.searchPhotographers(query);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error searching photographers: $e');
    }
  }
}
