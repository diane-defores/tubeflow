import 'package:flutter/material.dart';

import 'package:replayglowz_app/widgets/app_states.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title);
  }
}

class SettingsChoiceTile extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? Text(value) : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

Future<void> showSettingsChoiceDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String currentValue,
  required ValueChanged<String> onSelected,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: options.map((option) {
        return RadioListTile<String>(
          title: Text(option),
          value: option,
          // Keep the current app dialog pattern until selection UI is migrated.
          // ignore: deprecated_member_use
          groupValue: currentValue,
          // ignore: deprecated_member_use
          onChanged: (value) {
            if (value != null) {
              onSelected(value);
              Navigator.of(context).pop();
            }
          },
        );
      }).toList(),
    ),
  );
}
