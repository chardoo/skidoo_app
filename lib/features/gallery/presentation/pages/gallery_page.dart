import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_image_widget.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<GalleryBloc>().add(const GalleryLoadRequested());
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          title: const Text(
            'Gallery',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<GalleryBloc, GalleryState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    backgroundColor: Colors.grey,
                    color: Colors.purple,
                    strokeWidth: 10,
                  ),
                );
              }
              if (state.errorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                            color: Color.fromARGB(255, 221, 217, 217)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context
                            .read<GalleryBloc>()
                            .add(const GalleryLoadRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (state.photos.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder, size: 100),
                      Text(
                        'Empty Gallery',
                        style: TextStyle(
                            color: Color.fromARGB(255, 221, 217, 217)),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding:
                    const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  itemCount: state.photos.length,
                  itemBuilder: (context, index) {
                    return BlocProvider.value(
                      value: context.read<CartBloc>(),
                      child: GalleryImageWidget(
                          imageUrl: state.photos[index].url),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
