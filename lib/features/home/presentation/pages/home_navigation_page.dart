import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/search_results_page.dart';
import 'package:skidoo_app/features/home/presentation/widgets/search_item_widget.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/features/user_profile/presentation/pages/account_page.dart';
import 'package:skidoo_app/features/cart/presentation/pages/cart_page.dart';

class HomeNavigationPage extends StatelessWidget {
  const HomeNavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final homeBloc = context.read<HomeBloc>();
    final userState = context.watch<UserProfileBloc>().state;
    final state = context.watch<HomeBloc>().state;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag, size: 20,
                color: Color.fromARGB(255, 200, 199, 199)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size(double.infinity, 5),
          child: Divider(color: Color.fromARGB(255, 237, 233, 233)),
        ),
        leading: Container(
          margin: const EdgeInsets.only(top: 10),
          child: state.isSearching
              ? BackButton(
                  onPressed: () {
                    homeBloc.add(const HomeSearchClosed());
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                  },
                )
              : GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountPage()),
                  ),
                  child: CircleAvatar(
                    radius: 20.h,
                    backgroundColor: Colors.white,
                    child: Text(
                      userState.name.isNotEmpty ? userState.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
        ),
        title: Container(
          margin: const EdgeInsets.only(top: 10),
          height: 40,
          child: TextFormField(
            onTap: () => homeBloc.add(const HomeEventSearched('')),
            decoration: InputDecoration(
              suffixIcon: state.isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      color: const Color.fromARGB(255, 247, 245, 245),
                      onPressed: () {
                        SystemChannels.textInput.invokeMethod('TextInput.hide');
                        homeBloc.add(const HomeSearchClosed());
                      },
                    )
                  : const SizedBox.shrink(),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(5.0),
              ),
              fillColor: const Color.fromARGB(255, 74, 73, 73),
              filled: true,
              labelText: 'Search event',
              labelStyle: const TextStyle(
                color: Color.fromARGB(255, 200, 198, 198),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            onChanged: (value) {
              homeBloc.add(HomeEventSearched(value));
            },
          ),
        ),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state) {
    if (state.isSearching) {
      if (state.isLoadingEvents) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.events.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available_outlined, size: 100),
              Text('No event found!',
                  style: TextStyle(
                      color: Color.fromARGB(255, 221, 217, 217))),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: ListView.builder(
          itemCount: state.events.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: SearchItemWidget(
                event: state.events[index],
                onTap: () {
                  final event = state.events[index];
                  context.read<HomeBloc>().add(HomeImagesSearched(
                        eventId: event.id,
                        eventName: event.eventName,
                      ));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                              value: context.read<HomeBloc>(),
                              child: const SearchResultsPage(),
                            )),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 500,
          child: ListView(
            children: [
              CarouselSlider(
                items: [
                  _carouselItem(),
                  _carouselItem(),
                  _carouselItem(),
                ],
                options: CarouselOptions(
                  height: 180.0,
                  enlargeCenterPage: true,
                  autoPlay: true,
                  aspectRatio: 16 / 9,
                  autoPlayCurve: Curves.fastOutSlowIn,
                  enableInfiniteScroll: true,
                  autoPlayAnimationDuration:
                      const Duration(milliseconds: 800),
                  viewportFraction: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _carouselItem() {
    return Container(
      margin: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        image: const DecorationImage(
          image: NetworkImage(
              'https://res.cloudinary.com/dpakfvvhu/image/upload/v1641466489/sample.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
