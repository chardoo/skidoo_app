import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/cart/presentation/pages/cart_page.dart';
import 'package:skidoo_app/features/cart/presentation/widgets/image_with_add_to_cart_widget.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';

class SearchResultsPage extends StatelessWidget {
  static const routeName = '/searchresults';
  const SearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeBloc>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag, color: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
          ),
        ],
        title: const Text(
          'Search Results',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: _buildContent(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeState state) {
    if (state.isLoadingImages) {
      return const Center(
        child: CircularProgressIndicator(
            backgroundColor: Colors.grey, color: Colors.purple, strokeWidth: 10),
      );
    }
    if (state.searchImages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 100),
            Text('No images found',
                style:
                    TextStyle(color: Color.fromARGB(255, 221, 217, 217))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: state.searchImages.length,
        itemBuilder: (context, index) {
          return BlocProvider.value(
            value: context.read<CartBloc>(),
            child: ImageWithAddToCartWidget(
              photo: state.searchImages[index],
            ),
          );
        },
      ),
    );
  }
}
