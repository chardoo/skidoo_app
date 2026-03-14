import 'package:skidoo_app/models/photographer/photographerModel.dart';

abstract class PhotographerRepository {
  Future<List<PhotographerModel>> getPhotographers();
  Future<List<PhotographerModel>> searchPhotographers(String query);
}
