class PlayOnVideo {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? thumbnailPath;
  final String? thumbnailUrl;
  final int duration; // milisegundos
  final int fileSize; // bytes
  final DateTime dateAdded;
  final String folderName;
  final String folderPath;

  const PlayOnVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.thumbnailPath,
    this.thumbnailUrl,
    required this.duration,
    required this.fileSize,
    required this.dateAdded,
    required this.folderName,
    required this.folderPath,
  });

  String get durationFormatted {
    if (duration <= 0) return '';
    final dur = Duration(milliseconds: duration);
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    final seconds = dur.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeFormatted {
    if (fileSize <= 0) return '';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'fileSize': fileSize,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
        'folderName': folderName,
        'folderPath': folderPath,
      };

  factory PlayOnVideo.fromMap(Map<String, dynamic> map) => PlayOnVideo(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        author: map['author']?.toString() ?? 'Autor desconocido',
        filePath: map['filePath']?.toString() ?? '',
        thumbnailPath: map['thumbnailPath']?.toString(),
        thumbnailUrl: map['thumbnailUrl']?.toString(),
        duration: map['duration'] as int? ?? 0,
        fileSize: map['fileSize'] as int? ?? 0,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] as int? ?? 0),
        folderName: map['folderName']?.toString() ?? 'My videos',
        folderPath: map['folderPath']?.toString() ?? '',
      );

  PlayOnVideo copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? thumbnailPath,
    String? thumbnailUrl,
    int? duration,
    int? fileSize,
    DateTime? dateAdded,
    String? folderName,
    String? folderPath,
  }) {
    return PlayOnVideo(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      dateAdded: dateAdded ?? this.dateAdded,
      folderName: folderName ?? this.folderName,
      folderPath: folderPath ?? this.folderPath,
    );
  }
}
