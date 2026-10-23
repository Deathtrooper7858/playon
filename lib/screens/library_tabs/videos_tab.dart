import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import '../../providers/video_provider.dart';
import '../../theme.dart';
import '../video_player_screen.dart';

class VideosTab extends StatelessWidget {
  final String searchQuery;
  final VoidCallback? onExploreDownloads;

  const VideosTab({
    super.key,
    required this.searchQuery,
    this.onExploreDownloads,
  });

  List<PlayOnVideo> _filterVideos(List<PlayOnVideo> videos) {
    if (searchQuery.trim().isEmpty) return videos;
    final q = searchQuery.toLowerCase().trim();
    return videos.where((v) {
      return v.title.toLowerCase().contains(q) ||
          v.author.toLowerCase().contains(q) ||
          v.folderName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PlayOnTheme.purplePrimary),
          );
        }

        final filtered = _filterVideos(provider.filteredVideos);

        if (filtered.isEmpty) {
          return _buildEmptyState(context, provider);
        }

        return RefreshIndicator(
          color: PlayOnTheme.purplePrimary,
          backgroundColor: PlayOnTheme.bgCard,
          onRefresh: provider.loadVideos,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader(provider, filtered.length);
              }
              final video = filtered[index - 1];
              return _buildVideoCard(context, video, provider, filtered, index - 1);
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(VideoProvider provider, int count) {
    final folders = provider.folders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$count ${count == 1 ? 'video' : 'videos'}',
              style: const TextStyle(
                color: PlayOnTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (provider.selectedFolder != null)
              GestureDetector(
                onTap: () => provider.selectFolder(null),
                child: const Row(
                  children: [
                    Icon(Icons.clear_all_rounded, size: 16, color: PlayOnTheme.purpleGlow),
                    SizedBox(width: 4),
                    Text(
                      'Ver todas las carpetas',
                      style: TextStyle(color: PlayOnTheme.purpleGlow, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (folders.length > 1) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: provider.selectedFolder == null,
                  selectedColor: PlayOnTheme.purplePrimary.withValues(alpha: 0.3),
                  backgroundColor: PlayOnTheme.bgSurface,
                  labelStyle: TextStyle(
                    color: provider.selectedFolder == null ? PlayOnTheme.purpleGlow : PlayOnTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: provider.selectedFolder == null ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => provider.selectFolder(null),
                ),
                const SizedBox(width: 8),
                ...folders.map((f) {
                  final isSelected = provider.selectedFolder == f;
                  final folderCount = provider.folderCounts[f] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$f ($folderCount)'),
                      selected: isSelected,
                      selectedColor: PlayOnTheme.purplePrimary.withValues(alpha: 0.3),
                      backgroundColor: PlayOnTheme.bgSurface,
                      labelStyle: TextStyle(
                        color: isSelected ? PlayOnTheme.purpleGlow : PlayOnTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => provider.selectFolder(isSelected ? null : f),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildVideoCard(
    BuildContext context,
    PlayOnVideo video,
    VideoProvider provider,
    List<PlayOnVideo> playlist,
    int initialIndex,
  ) {
    final isFav = provider.isFavorite(video.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: PlayOnTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlayOnTheme.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => VideoPlayerScreen.open(
          context,
          video,
          playlist: playlist,
          initialIndex: initialIndex,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura 16:9
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: PlayOnTheme.bgSurface,
                    child: _buildThumbnailImage(video),
                  ),
                ),
                // Botón Play central semitransparente
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ),
                // Chip de duración en la esquina inferior derecha
                if (video.durationFormatted.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        video.durationFormatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Chip de carpeta en la esquina superior izquierda
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PlayOnTheme.purpleGlow.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_rounded, size: 12, color: PlayOnTheme.purpleGlow),
                        const SizedBox(width: 4),
                        Text(
                          video.folderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Metadatos y acciones inferiores
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: const TextStyle(
                            color: PlayOnTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                video.author,
                                style: const TextStyle(
                                  color: PlayOnTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (video.fileSizeFormatted.isNotEmpty) ...[
                              const Text(' · ', style: TextStyle(color: PlayOnTheme.textTertiary)),
                              Text(
                                video.fileSizeFormatted,
                                style: const TextStyle(
                                  color: PlayOnTheme.textTertiary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? PlayOnTheme.pinkAccent : PlayOnTheme.textTertiary,
                      size: 20,
                    ),
                    tooltip: isFav ? 'Quitar de favoritos' : 'Añadir a favoritos',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => provider.toggleFavorite(video.id),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: PlayOnTheme.textSecondary, size: 20),
                    color: PlayOnTheme.bgCard,
                    onSelected: (action) {
                      if (action == 'delete') {
                        _confirmDelete(context, video, provider);
                      } else if (action == 'play') {
                        VideoPlayerScreen.open(
                          context,
                          video,
                          playlist: playlist,
                          initialIndex: initialIndex,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'play',
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_outline_rounded, color: PlayOnTheme.purpleGlow, size: 18),
                            SizedBox(width: 10),
                            Text('Reproducir video', style: TextStyle(color: PlayOnTheme.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350), size: 18),
                            SizedBox(width: 10),
                            Text('Eliminar video', style: TextStyle(color: Color(0xFFEF5350), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailImage(PlayOnVideo video) {
    if (video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()) {
      return Image.file(
        File(video.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        video.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PlayOnTheme.purplePrimary.withValues(alpha: 0.3),
            PlayOnTheme.bgSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_rounded, color: PlayOnTheme.textTertiary, size: 40),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlayOnVideo video, VideoProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayOnTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar video?', style: TextStyle(color: PlayOnTheme.textPrimary)),
        content: Text(
          'Se eliminará permanentemente "${video.title}" de tu dispositivo.',
          style: const TextStyle(color: PlayOnTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: PlayOnTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteVideo(video);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, VideoProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: PlayOnTheme.primaryGradient,
                boxShadow: PlayOnTheme.glowShadow(blur: 24),
              ),
              child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              searchQuery.trim().isNotEmpty
                  ? 'Sin resultados para "$searchQuery"'
                  : 'No hay videos descargados',
              style: const TextStyle(
                color: PlayOnTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.trim().isNotEmpty
                  ? 'Intenta con otro término o revisa otra carpeta.'
                  : 'Descarga videos de YouTube en la sección de Descargas eligiendo la carpeta "My videos" o tu carpeta personalizada.',
              style: const TextStyle(
                color: PlayOnTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onExploreDownloads != null)
              ElevatedButton.icon(
                onPressed: onExploreDownloads,
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: const Text('Ir a Descargas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PlayOnTheme.purplePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
          ],
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}
