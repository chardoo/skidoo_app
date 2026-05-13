import 'dart:io';

import 'package:skidoo_app/models/photographer/photographer_event.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

abstract class PhotographerRepository {
  Future<List<PhotographerModel>> getPhotographers();
  Future<List<PhotographerModel>> searchPhotographers(String query);
  Future<List<PhotographerSample>> getSamples(String photographerId);
  Future<List<PhotographerSample>> uploadSamples({
    required String photographerId,
    required List<File> files,
  });
  Future<void> deleteSample({
    required String sampleId,
    required String photographerId,
  });
  Future<PhotographerEventsResult> getPhotographerEvents({
    required String photographerId,
    required int page,
    required int limit,
  });
}
