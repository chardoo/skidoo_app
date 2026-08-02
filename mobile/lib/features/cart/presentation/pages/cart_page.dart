import 'package:flutter/material.dart';
import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/cart/presentation/pages/checkout_page.dart';
import 'package:skidoo_app/features/cart/presentation/widgets/cart_item_widget.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

class CartPage extends StatelessWidget {
  static const routeName = '/cart';
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CartBloc>(),
      child: const _CartView(),
    );
  }
}

class _CartView extends StatelessWidget {
  const _CartView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartBloc, CartState>(
      listener: (context, state) {
        if (state.status == CartStatus.paymentInitiated &&
            state.paymentUrl != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<CartBloc>(),
                child: CheckoutPage(url: state.paymentUrl!),
              ),
            ),
          );
        }
        if (state.status == CartStatus.paymentSuccess) {
          AppSnackBar.success(
              context, state.successMessage ?? 'Payment successful!');
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (_) => false);
        }
        if (state.status == CartStatus.paymentFailure &&
            state.errorMessage != null) {
          AppSnackBar.error(context, state.errorMessage!);
        }
        if (state.status == CartStatus.downloadSuccess) {
          AppSnackBar.success(context, 'Image downloaded successfully.');
        }
        if (state.status == CartStatus.downloadFailure &&
            state.errorMessage != null) {
          AppSnackBar.error(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        final page = Scaffold(
          appBar: AppBar(
            backgroundColor: ext.homeBackground,
            title: Text(
              'My Cart',
              style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp),
            ),
          ),
          body: SafeArea(
            child: state.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image,
                            size: 80.sp, color: ext.searchHintColor),
                        Text(
                          'Cart Empty',
                          style: TextStyle(
                              fontSize: 16.sp, color: ext.searchHintColor),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(10.w),
                    child: MediaGrid(
                      density: MediaGridDensity.cards,
                      itemCount: state.items.length,
                      itemBuilder: (context, index) =>
                          CartItemWidget(photo: state.items[index]),
                    ),
                  ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: state.items.isNotEmpty
              ? AppButton(
                  width: 343.w,
                  isLoading: state.status == CartStatus.paymentLoading,
                  label: 'Pay ${state.totalAmount}',
                  onPressed: state.totalAmount > 0
                      ? () => context
                          .read<CartBloc>()
                          .add(const CartPaymentInitiated())
                      : null,
                )
              : null,
        );
        return webWrap(page, backgroundColor: ext.homeBackground);
      },
    );
  }

}
