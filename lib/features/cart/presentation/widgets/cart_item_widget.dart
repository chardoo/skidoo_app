import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class CartItemWidget extends StatelessWidget {
  final Photo photo;
  const CartItemWidget({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            photo.url,
            fit: BoxFit.contain,
            height: 250,
            errorBuilder: (_, __, ___) => Container(
              height: 250,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 60),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            onPressed: () {
              context.read<CartBloc>().add(CartItemRemoved(photo));
            },
            icon: const Icon(
              Icons.remove_circle,
              color: Color.fromARGB(255, 251, 250, 250),
              size: 40,
            ),
          ),
        ),
      ],
    );
  }
}
