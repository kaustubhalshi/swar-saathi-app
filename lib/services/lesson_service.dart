import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson_model.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'lessons';

  // Get lessons by genre
  Future<List<Lesson>> getLessonsByGenre(String genre) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('genre', isEqualTo: genre)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => Lesson.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching lessons: $e');
      throw Exception('Failed to load lessons: $e');
    }
  }

  // Get lesson by ID
  Future<Lesson?> getLessonById(String lessonId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(lessonId).get();

      if (doc.exists) {
        return Lesson.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching lesson: $e');
      throw Exception('Failed to load lesson: $e');
    }
  }

  // Get all lessons
  Future<List<Lesson>> getAllLessons() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('genre')
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => Lesson.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching all lessons: $e');
      throw Exception('Failed to load lessons: $e');
    }
  }

  // Add a new lesson (for admin use)
  Future<String> addLesson(Lesson lesson) async {
    try {
      final docRef = await _firestore.collection(_collection).add(lesson.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding lesson: $e');
      throw Exception('Failed to add lesson: $e');
    }
  }

  // Update lesson
  Future<void> updateLesson(String lessonId, Lesson lesson) async {
    try {
      await _firestore.collection(_collection).doc(lessonId).update(lesson.toFirestore());
    } catch (e) {
      print('Error updating lesson: $e');
      throw Exception('Failed to update lesson: $e');
    }
  }

  // Delete lesson (soft delete by setting isActive to false)
  Future<void> deleteLesson(String lessonId) async {
    try {
      await _firestore.collection(_collection).doc(lessonId).update({
        'isActive': false,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error deleting lesson: $e');
      throw Exception('Failed to delete lesson: $e');
    }
  }
}