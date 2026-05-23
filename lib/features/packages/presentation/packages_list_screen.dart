import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/packages_providers.dart';
import '../domain/package.dart';
import '../domain/package_status.dart';
import 'widgets/package_card.dart';

/// Filtros de status disponíveis na lista. `null` significa "todos".
const List<(String, PackageStatus?)> _statusFilters = [
  ('Todos', null),
  ('Aguardando', PackageStatus.awaitingPickup),
  ('Pendentes', PackageStatus.pendingIdentification),
  ('Entregues', PackageStatus.delivered),
  ('Devolvidos', PackageStatus.returned),
];

/// Lista de pacotes com busca e filtro por status.
class PackagesListScreen extends ConsumerStatefulWidget {
  const PackagesListScreen({super.key});

  @override
  ConsumerState<PackagesListScreen> createState() => _PackagesListScreenState();
}

class _PackagesListScreenState extends ConsumerState<PackagesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  PackageStatus? _statusFilter;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Package> _applyFilters(List<Package> packages) {
    final query = _query.trim().toLowerCase();
    final result = packages.where((package) {
      if (_statusFilter != null && package.status != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final recipient = package.recipientName?.toLowerCase() ?? '';
      final unit = package.unit?.toLowerCase() ?? '';
      final tracking = package.trackingCode.toLowerCase();
      return recipient.contains(query) ||
          unit.contains(query) ||
          tracking.contains(query);
    }).toList();
    result.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final asyncPackages = ref.watch(packagesProvider);
    final allPackages = asyncPackages.asData?.value ?? const <Package>[];
    final packages = _applyFilters(allPackages);
    final hasQueryOrFilter = _query.isNotEmpty || _statusFilter != null;
    final isLoading = asyncPackages.isLoading && allPackages.isEmpty;
    final loadError = asyncPackages.hasError ? asyncPackages.error : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Pacotes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar por morador, unidade ou código',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (label, status) = _statusFilters[index];
                return ChoiceChip(
                  label: Text(label),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: switch ((isLoading, loadError, packages.isEmpty)) {
              (true, _, _) => const Center(child: CircularProgressIndicator()),
              (_, final Object _, _) => _ErrorView(
                onRetry: () => ref.invalidate(packagesProvider),
              ),
              (_, _, true) => _EmptyState(filtered: hasQueryOrFilter),
              _ => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(packagesProvider);
                  await ref.read(packagesProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final package = packages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PackageCard(
                        package: package,
                        onTap: () =>
                            context.push('/packages/${package.id}'),
                      ),
                    );
                  },
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar os pacotes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  /// `true` quando a lista está vazia por causa de busca/filtro.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off : Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'Nenhum pacote encontrado' : 'Nenhum pacote ainda',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'Ajuste a busca ou os filtros.'
                  : 'Toque em "Escanear" para registrar o primeiro.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
