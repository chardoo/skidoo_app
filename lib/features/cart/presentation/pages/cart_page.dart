import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/cart/presentation/pages/checkout_page.dart';
import 'package:skidoo_app/features/cart/presentation/widgets/cart_item_widget.dart';

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
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.successMessage ?? 'Payment successful!'),
              backgroundColor: Colors.green,
            ));
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (_) => false);
        }
        if (state.status == CartStatus.paymentFailure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ));
        }
        if (state.status == CartStatus.downloadSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Image downloaded successfully.'),
              backgroundColor: Colors.green,
            ));
        }
        if (state.status == CartStatus.downloadFailure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'My Cart',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          body: SafeArea(
            child: state.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 100),
                        Text(
                          'Cart Empty',
                          style: TextStyle(
                              color: Color.fromARGB(255, 221, 217, 217)),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        return CartItemWidget(photo: state.items[index]);
                      },
                    ),
                  ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: state.items.isNotEmpty
              ? state.status == CartStatus.paymentLoading
                  ? const CircularProgressIndicator()
                  : CustomButton(
                      width: 343,
                      height: 50,
                      label: 'Pay ${state.totalAmount}',
                      ontap: state.totalAmount > 0
                          ? () => context
                              .read<CartBloc>()
                              .add(const CartPaymentInitiated())
                          : null,
                    )
              : null,
        );
      },
    );
  }
}
