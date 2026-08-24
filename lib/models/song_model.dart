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
  final String filePath;

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
    String? filePath,
  }) : filePath = filePath ?? uri;

  String get durationFormatted {
    final minutes = (duration / 60000).floor();
    final seconds = ((duration % 60000) / 1000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  PlayOnSong copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? albumArt,
    String? uri,
    int? duration,
    String? folderName,
    String? folderPath,
    String? filePath,
  }) {
    return PlayOnSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      uri: uri ?? this.uri,
      duration: duration ?? this.duration,
      folderName: folderName ?? this.folderName,
      folderPath: folderPath ?? this.folderPath,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayOnSong &&
        other.id == id &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.albumArt == albumArt &&
        other.uri == uri &&
        other.duration == duration &&
        other.folderName == folderName &&
        other.folderPath == folderPath &&
        other.filePath == filePath;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      artist,
      album,
      albumArt,
      uri,
      duration,
      folderName,
      folderPath,
      filePath,
    );
  }
}

