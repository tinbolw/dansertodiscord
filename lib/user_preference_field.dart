import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferenceField extends StatefulWidget {
  final String label;
  final String keyName;
  final TextEditingController? controller;

  const UserPreferenceField({super.key, required this.label, required this.keyName, this.controller});

  @override
  State<UserPreferenceField> createState() => _UserPreferenceFieldState();
}

class _UserPreferenceFieldState extends State<UserPreferenceField> {
  late final controller = widget.controller ?? TextEditingController();

  @override
  void initState() {
    super.initState();

    _loadUserPreference();

    controller.addListener(_saveUserPreference);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _loadUserPreference() async {
    final prefs = await SharedPreferences.getInstance();
    controller.text = prefs.getString(widget.keyName) ?? "";
  }

  void _saveUserPreference() async {
    final text = controller.text;
    final prefs = await SharedPreferences.getInstance();

    prefs.setString(widget.keyName, text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(labelText: widget.label),
      controller: controller,
    );
  }
}