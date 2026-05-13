import 'dart:io';

import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/photographers/data/datasources/photographer_remote_data_source.dart';
import 'package:skidoo_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:skidoo_app/models/photographer/photographer_event.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
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

  @override
  Future<List<PhotographerSample>> getSamples(String photographerId) async {
    try {
      return await _remoteDataSource.getSamples(photographerId);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error loading samples: $e');
    }
  }

  @override
  Future<List<PhotographerSample>> uploadSamples({
    required String photographerId,
    required List<File> files,
  }) async {
    try {
      return await _remoteDataSource.uploadSamples(
          photographerId: photographerId, files: files);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error uploading samples: $e');
    }
  }

  @override
  Future<void> deleteSample({
    required String sampleId,
    required String photographerId,
  }) async {
    try {
      await _remoteDataSource.deleteSample(
          sampleId: sampleId, photographerId: photographerId);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error deleting sample: $e');
    }
  }

  @override
  Future<PhotographerEventsResult> getPhotographerEvents({
    required String photographerId,
    required int page,
    required int limit,
  }) async {
    try {
      return await _remoteDataSource.getPhotographerEvents(
        photographerId: photographerId,
        page: page,
        limit: limit,
      );
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error loading photographer events: $e');
    }
  }
}
