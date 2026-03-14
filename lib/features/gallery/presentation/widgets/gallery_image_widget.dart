import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';

class GalleryImageWidget extends StatelessWidget {
  final String imageUrl;
  const GalleryImageWidget({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              context.read<CartBloc>().add(CartImageDownloaded(imageUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading image...')),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(255, 242, 239, 239),
              ),
              child: const Icon(Icons.download, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}
