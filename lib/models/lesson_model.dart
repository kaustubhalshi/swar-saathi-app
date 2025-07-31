class Lesson {
  final String id;
  final String title;
  final String description;
  final String content;
  final String genre;
  final String difficulty;
  final int duration; // in minutes
  final String audioUrl;
  final String videoUrl;
  final String practiceUrl;
  final List<String> tags;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PracticeNote> practiceNotes; // New field for practice notes

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.genre,
    required this.difficulty,
    required this.duration,
    required this.audioUrl,
    required this.videoUrl,
    required this.practiceUrl,
    required this.tags,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.practiceNotes,
  });

  factory Lesson.fromFirestore(Map<String, dynamic> data, String id) {
    List<PracticeNote> notes = [];
    if (data['practiceNotes'] != null) {
      notes = (data['practiceNotes'] as List)
          .map((noteData) => PracticeNote.fromMap(noteData))
          .toList();
    }

    return Lesson(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      content: data['content'] ?? '',
      genre: data['genre'] ?? '',
      difficulty: data['difficulty'] ?? 'beginner',
      duration: data['duration'] ?? 0,
      audioUrl: data['audioUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      practiceUrl: data['practiceUrl'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updatedAt'] ?? 0),
      practiceNotes: notes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'content': content,
      'genre': genre,
      'difficulty': difficulty,
      'duration': duration,
      'audioUrl': audioUrl,
      'videoUrl': videoUrl,
      'practiceUrl': practiceUrl,
      'tags': tags,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'practiceNotes': practiceNotes.map((note) => note.toMap()).toList(),
    };
  }
}

class PracticeNote {
  final int startTime; // in milliseconds
  final int endTime; // in milliseconds
  final String note; // Sa, Re, Ga, etc.
  final double frequency; // Hz
  final String swarNotation; // Devanagari notation
  final int octave;

  PracticeNote({
    required this.startTime,
    required this.endTime,
    required this.note,
    required this.frequency,
    required this.swarNotation,
    required this.octave,
  });

  factory PracticeNote.fromMap(Map<String, dynamic> data) {
    return PracticeNote(
      startTime: data['startTime'] ?? 0,
      endTime: data['endTime'] ?? 0,
      note: data['note'] ?? '',
      frequency: (data['frequency'] ?? 0.0).toDouble(),
      swarNotation: data['swarNotation'] ?? '',
      octave: data['octave'] ?? 4,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'note': note,
      'frequency': frequency,
      'swarNotation': swarNotation,
      'octave': octave,
    };
  }
}