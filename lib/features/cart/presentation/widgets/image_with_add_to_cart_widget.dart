import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class ImageWithAddToCartWidget extends StatelessWidget {
  final Photo photo;
  const ImageWithAddToCartWidget({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            photo.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                color: Colors.black,
                height: 40.h,
                width: 40.h,
                child: Text(
                  'GhC ${photo.price}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.h,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              SizedBox(height: 155.h),
              Container(
                padding: const EdgeInsets.all(5),
                color: Colors.black,
                height: 40.h,
                width: 40.h,
                child: photo.price == 0
                    ? GestureDetector(
                        onTap: () {
                          context
                              .read<CartBloc>()
                              .add(CartImageDownloaded(photo.url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Downloading...')),
                          );
                        },
                        child: const Icon(Icons.download, size: 20),
                      )
                    : GestureDetector(
                        onTap: () {
                          context
                              .read<CartBloc>()
                              .add(CartItemAdded(photo));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Added to cart')),
                          );
                        },
                        child: const Icon(Icons.shopping_cart, size: 20),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
