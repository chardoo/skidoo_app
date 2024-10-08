import 'package:get/get.dart';
import 'package:skidoo_app/services/auth_service.dart';

class GetAuthService extends GetxService {
  Future<GetAuthService> init() async => this;

  var isloggedIn = false;
  var token = '';
  AuthService service = AuthService();
  @override
  void onInit() async {
    // isloggedIn = await AuthService.getisloggedIn();
    token = await AuthService.getToken();
    super.onInit();
  }
}
