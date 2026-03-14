import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/photographer_tile_widget.dart';

class PhotographersPage extends StatelessWidget {
  const PhotographersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Photographers'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
                top: 10, left: 20, right: 20, bottom: 20),
            height: 40,
            child: TextFormField(
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  color: const Color.fromARGB(255, 247, 245, 245),
                  onPressed: () {
                    context
                        .read<PhotographerBloc>()
                        .add(const PhotographersLoadRequested());
                  },
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(5.0),
                ),
                fillColor: const Color.fromARGB(255, 74, 73, 73),
                filled: true,
                labelText: 'Search',
                labelStyle: const TextStyle(
                  color: Color.fromARGB(255, 200, 198, 198),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              onChanged: (value) {
                context
                    .read<PhotographerBloc>()
                    .add(PhotographersSearched(value));
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<PhotographerBloc, PhotographerState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (state.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(state.errorMessage!,
                            style: const TextStyle(
                                color:
                                    Color.fromARGB(255, 221, 217, 217))),
                        TextButton(
                          onPressed: () => context
                              .read<PhotographerBloc>()
                              .add(const PhotographersLoadRequested()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (state.photographers.isEmpty) {
                  return const Center(
                    child: Text('No photographers found.',
                        style: TextStyle(
                            color:
                                Color.fromARGB(255, 221, 217, 217))),
                  );
                }
                return Container(
                  margin:
                      const EdgeInsets.only(left: 16, right: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: state.photographers.length,
                    itemBuilder: (context, index) {
                      return PhotographerTileWidget(
                          photographer: state.photographers[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
