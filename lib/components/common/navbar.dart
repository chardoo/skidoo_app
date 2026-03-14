import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/constants/icons.dart';

class AppNavbar extends StatefulWidget {
  const AppNavbar(
      {super.key, required this.selectedIndex, required this.onchange});
  final int selectedIndex;
  final Function(int index) onchange;

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  @override
  void initState() {
    _selectedIndex = widget.selectedIndex;
    super.initState();
  }

  late int _selectedIndex;
  @override
  Widget build(BuildContext context) {
    return 
    
    
     BottomNavigationBar(
        elevation: 10.h,
        currentIndex: _selectedIndex,
        onTap: (index) {
          _selectedIndex = index;
          widget.onchange(index);
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: const Color.fromARGB(255, 255, 255, 255),
        items: const [
          BottomNavigationBarItem(
            icon: _PasiveIcon(
              iconPath: IconsPath.home,
            ),
            activeIcon: _ActiveIcon(label: "Home", iconPath: IconsPath.home),
            label: "",
          ),
          BottomNavigationBarItem(
              icon: _PasiveIcon(iconPath: IconsPath.gallery),
              activeIcon:
                  _ActiveIcon(iconPath: IconsPath.gallery, label: "Gallery"),
              label: ""),
          BottomNavigationBarItem(
              icon: _PasiveIcon(iconPath: IconsPath.photographer),
              activeIcon: _ActiveIcon(
                  iconPath: IconsPath.photographer, label: "Photographer"),
              label: ""),
        ],
      
    )
    
    ;
    ;
  }
}

class _PasiveIcon extends StatelessWidget {
  const _PasiveIcon({
    required this.iconPath,
  });

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      iconPath,
      width: 30.h,
      height: 30.h,
      color: Colors.white,
    );
  }
}

class _ActiveIcon extends StatelessWidget {
  const _ActiveIcon({
    required this.iconPath,
    required this.label,
  });
  final String iconPath;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.h,
      padding: EdgeInsets.all(8.h),
      margin: EdgeInsets.only(top: 8.h, right: 8.h, left: 8.h),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.h),
          color: Theme.of(context).primaryColor.withOpacity(0.5)),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Image.asset(
            width: 30.h,
            height: 20.h,
            iconPath,
            color: const Color.fromARGB(255, 255, 255, 255),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12.h, color: const Color.fromARGB(255, 255, 255, 255)),
          )
        ],
      ),
    );
  }
}
