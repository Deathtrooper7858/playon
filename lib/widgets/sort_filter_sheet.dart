import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme.dart';

class SortFilterSheet extends StatelessWidget {
  const SortFilterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SortFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final currentSort = provider.sortOption;
    final isAsc = provider.sortAscending;

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: PlayOnTheme.bgCard.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: PlayOnTheme.glassBorder, width: 1.5),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ordenar canciones',
                        style: TextStyle(
                          color: PlayOnTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      provider.setSortOption(currentSort, ascending: !isAsc);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PlayOnTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PlayOnTheme.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 16,
                            color: PlayOnTheme.purpleGlow,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isAsc ? 'Ascendente' : 'Descendente',
                            style: const TextStyle(
                              color: PlayOnTheme.purpleGlow,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: PlayOnTheme.divider),
              _buildOption(
                context,
                title: 'Título de la canción',
                subtitle: 'Alfabéticamente por nombre',
                icon: Icons.sort_by_alpha_rounded,
                selected: currentSort == SongSortOption.title,
                onTap: () {
                  provider.setSortOption(SongSortOption.title);
                  Navigator.pop(context);
                },
              ),
              _buildOption(
                context,
                title: 'Artista',
                subtitle: 'Agrupado por creador musical',
                icon: Icons.person_rounded,
                selected: currentSort == SongSortOption.artist,
                onTap: () {
                  provider.setSortOption(SongSortOption.artist);
                  Navigator.pop(context);
                },
              ),
              _buildOption(
                context,
                title: 'Álbum',
                subtitle: 'Por nombre de álbum o disco',
                icon: Icons.album_rounded,
                selected: currentSort == SongSortOption.album,
                onTap: () {
                  provider.setSortOption(SongSortOption.album);
                  Navigator.pop(context);
                },
              ),
              _buildOption(
                context,
                title: 'Duración',
                subtitle: 'Por tiempo total de pista',
                icon: Icons.timer_outlined,
                selected: currentSort == SongSortOption.duration,
                onTap: () {
                  provider.setSortOption(SongSortOption.duration);
                  Navigator.pop(context);
                },
              ),
              _buildOption(
                context,
                title: 'Fecha / ID de agregado',
                subtitle: 'Por orden cronológico de escaneo',
                icon: Icons.calendar_today_rounded,
                selected: currentSort == SongSortOption.date,
                onTap: () {
                  provider.setSortOption(SongSortOption.date);
                  Navigator.pop(context);
                },
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? PlayOnTheme.purplePrimary.withValues(alpha: 0.2) : PlayOnTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? PlayOnTheme.purplePrimary : PlayOnTheme.divider,
          ),
        ),
        child: Icon(
          icon,
          color: selected ? PlayOnTheme.purpleGlow : PlayOnTheme.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? PlayOnTheme.purpleGlow : PlayOnTheme.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: PlayOnTheme.textTertiary,
          fontSize: 12,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: PlayOnTheme.purplePrimary, size: 22)
          : null,
      onTap: onTap,
    );
  }
}
