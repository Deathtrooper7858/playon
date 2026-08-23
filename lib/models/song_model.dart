class PlayOnSong {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String? albumArt;
  final String uri;
  final int duration;
  final String? folderName;
  final String? folderPath;

  PlayOnSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
    required this.uri,
    required this.duration,
    this.folderName,
    this.folderPath,
  });

  String get durationFormatted {
    final minutes = (duration / 60000).floor();
    final seconds = ((duration % 60000) / 1000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
