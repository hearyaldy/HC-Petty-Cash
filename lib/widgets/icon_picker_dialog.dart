import 'package:flutter/material.dart';

class IconPickerDialog extends StatefulWidget {
  final IconData? initialIcon;

  const IconPickerDialog({super.key, this.initialIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  IconData? _selectedIcon;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _availableIcons = [
    {'icon': Icons.attach_money, 'name': 'Money'},
    {'icon': Icons.shopping_cart, 'name': 'Shopping'},
    {'icon': Icons.restaurant, 'name': 'Restaurant'},
    {'icon': Icons.flight, 'name': 'Flight'},
    {'icon': Icons.hotel, 'name': 'Hotel'},
    {'icon': Icons.directions_car, 'name': 'Car'},
    {'icon': Icons.local_gas_station, 'name': 'Gas'},
    {'icon': Icons.coffee, 'name': 'Coffee'},
    {'icon': Icons.phone, 'name': 'Phone'},
    {'icon': Icons.computer, 'name': 'Computer'},
    {'icon': Icons.print, 'name': 'Print'},
    {'icon': Icons.email, 'name': 'Email'},
    {'icon': Icons.bolt, 'name': 'Electric'},
    {'icon': Icons.water_drop, 'name': 'Water'},
    {'icon': Icons.business, 'name': 'Business'},
    {'icon': Icons.home, 'name': 'Home'},
    {'icon': Icons.build, 'name': 'Build'},
    {'icon': Icons.cleaning_services, 'name': 'Cleaning'},
    {'icon': Icons.local_hospital, 'name': 'Medical'},
    {'icon': Icons.school, 'name': 'Education'},
    {'icon': Icons.book, 'name': 'Book'},
    {'icon': Icons.sports, 'name': 'Sports'},
    {'icon': Icons.music_note, 'name': 'Music'},
    {'icon': Icons.camera, 'name': 'Camera'},
    {'icon': Icons.palette, 'name': 'Art'},
    {'icon': Icons.theater_comedy, 'name': 'Entertainment'},
    {'icon': Icons.celebration, 'name': 'Celebration'},
    {'icon': Icons.card_giftcard, 'name': 'Gift'},
    {'icon': Icons.local_shipping, 'name': 'Shipping'},
    {'icon': Icons.inventory, 'name': 'Inventory'},
    {'icon': Icons.science, 'name': 'Science'},
    {'icon': Icons.agriculture, 'name': 'Agriculture'},
    {'icon': Icons.factory, 'name': 'Factory'},
    {'icon': Icons.construction, 'name': 'Construction'},
    {'icon': Icons.handyman, 'name': 'Tools'},
    {'icon': Icons.engineering, 'name': 'Engineering'},
    {'icon': Icons.design_services, 'name': 'Design'},
    {'icon': Icons.calculate, 'name': 'Calculate'},
    {'icon': Icons.insights, 'name': 'Analytics'},
    {'icon': Icons.trending_up, 'name': 'Growth'},
    {'icon': Icons.assessment, 'name': 'Assessment'},
    {'icon': Icons.account_balance, 'name': 'Bank'},
    {'icon': Icons.credit_card, 'name': 'Card'},
    {'icon': Icons.receipt_long, 'name': 'Receipt'},
    {'icon': Icons.qr_code, 'name': 'QR Code'},
    {'icon': Icons.store, 'name': 'Store'},
    {'icon': Icons.storefront, 'name': 'Shop'},
    {'icon': Icons.shopping_bag, 'name': 'Bag'},
    {'icon': Icons.local_mall, 'name': 'Mall'},
    {'icon': Icons.local_cafe, 'name': 'Cafe'},
    {'icon': Icons.local_pizza, 'name': 'Pizza'},
    {'icon': Icons.fastfood, 'name': 'Fast Food'},
    {'icon': Icons.lunch_dining, 'name': 'Lunch'},
    {'icon': Icons.dinner_dining, 'name': 'Dinner'},
    {'icon': Icons.local_bar, 'name': 'Bar'},
    {'icon': Icons.liquor, 'name': 'Liquor'},
    {'icon': Icons.bakery_dining, 'name': 'Bakery'},
    {'icon': Icons.icecream, 'name': 'Ice Cream'},
    {'icon': Icons.emoji_food_beverage, 'name': 'Beverage'},
    {'icon': Icons.medical_services, 'name': 'Medical'},
    {'icon': Icons.vaccines, 'name': 'Vaccine'},
    {'icon': Icons.medication, 'name': 'Medication'},
    {'icon': Icons.spa, 'name': 'Spa'},
    {'icon': Icons.fitness_center, 'name': 'Fitness'},
    {'icon': Icons.pool, 'name': 'Pool'},
    {'icon': Icons.beach_access, 'name': 'Beach'},
    {'icon': Icons.park, 'name': 'Park'},
    {'icon': Icons.forest, 'name': 'Forest'},
    {'icon': Icons.pets, 'name': 'Pets'},
    {'icon': Icons.child_care, 'name': 'Child Care'},
    {'icon': Icons.elderly, 'name': 'Elderly'},
    {'icon': Icons.accessible, 'name': 'Accessible'},
    {'icon': Icons.volunteer_activism, 'name': 'Charity'},
    {'icon': Icons.favorite, 'name': 'Favorite'},
    {'icon': Icons.star, 'name': 'Star'},
    {'icon': Icons.workspace_premium, 'name': 'Premium'},
    {'icon': Icons.verified, 'name': 'Verified'},
    {'icon': Icons.security, 'name': 'Security'},
    {'icon': Icons.lock, 'name': 'Lock'},
    {'icon': Icons.vpn_key, 'name': 'Key'},
    {'icon': Icons.badge, 'name': 'Badge'},
    {'icon': Icons.notifications, 'name': 'Notification'},
    {'icon': Icons.alarm, 'name': 'Alarm'},
    {'icon': Icons.schedule, 'name': 'Schedule'},
    {'icon': Icons.calendar_today, 'name': 'Calendar'},
    {'icon': Icons.event, 'name': 'Event'},
    {'icon': Icons.wb_sunny, 'name': 'Sunny'},
    {'icon': Icons.wb_cloudy, 'name': 'Cloudy'},
    {'icon': Icons.ac_unit, 'name': 'Cold'},
    {'icon': Icons.whatshot, 'name': 'Hot'},
    {'icon': Icons.eco, 'name': 'Eco'},
    {'icon': Icons.recycling, 'name': 'Recycle'},
    {'icon': Icons.light_mode, 'name': 'Light'},
    {'icon': Icons.dark_mode, 'name': 'Dark'},
    {'icon': Icons.more_horiz, 'name': 'More'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon;
  }

  List<Map<String, dynamic>> get _filteredIcons {
    if (_searchQuery.isEmpty) {
      return _availableIcons;
    }
    return _availableIcons
        .where((item) =>
            (item['name'] as String)
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Icon',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search icons',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedIcon != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  children: [
                    Icon(_selectedIcon, size: 32, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text('Selected Icon',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _filteredIcons.length,
                itemBuilder: (context, index) {
                  final item = _filteredIcons[index];
                  final icon = item['icon'] as IconData;
                  final name = item['name'] as String;
                  final isSelected = _selectedIcon?.codePoint == icon.codePoint;

                  return Tooltip(
                    message: name,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.blue : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedIcon == null
                      ? null
                      : () => Navigator.pop(context, _selectedIcon),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
