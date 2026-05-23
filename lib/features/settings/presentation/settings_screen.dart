import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../application/theme_controller.dart';

/// Configurações do app: tema e informações da versão.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disponível na versão completa.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ThemeMode currentMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Aparência',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: currentMode,
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).setMode(mode);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('Automático'),
                    subtitle: Text('Segue o sistema'),
                    value: ThemeMode.system,
                  ),
                  Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: Text('Claro'),
                    value: ThemeMode.light,
                  ),
                  Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: Text('Escuro'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sobre',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Versão'),
                  trailing: Text('1.0.0 (protótipo)'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.public),
                  title: Text('Ambiente'),
                  trailing: Text(
                    Env.environment,
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Legal',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de privacidade'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () =>
                      _showUnavailable(context, 'Política de privacidade'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Termos de uso'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showUnavailable(context, 'Termos de uso'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Solicitar exclusão da conta',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () =>
                      _showUnavailable(context, 'Exclusão de conta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
