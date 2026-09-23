import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/hazard_report.dart';
import '../models/shift_log.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users ---

  Future<void> createUserProfile(UserProfile user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap()).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Firestore timeout or error in createUserProfile: $e');
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get().timeout(const Duration(seconds: 10));
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Firestore timeout or error in getUserProfile: $e');
      return null;
    }
  }

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    }).timeout(const Duration(seconds: 10));
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // --- Hazards ---
  
  Future<void> reportHazard(HazardReport report) async {
    await _db.collection('hazards').add(report.toMap());
  }

  Stream<List<HazardReport>> streamActiveHazards() {
    return _db
        .collection('hazards')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HazardReport.fromFirestore(doc))
            .toList());
  }

  Future<void> resolveHazard(String hazardId) async {
    await _db.collection('hazards').doc(hazardId).update({'isActive': false});
  }

  // --- Shifts ---
  
  Future<String> startShift(ShiftLog shift) async {
    final docRef = await _db.collection('shifts').add(shift.toMap());
    return docRef.id;
  }

  Future<void> endShift(String shiftId, Map<String, dynamic> updateData) async {
    await _db.collection('shifts').doc(shiftId).update(updateData);
  }

  Stream<List<ShiftLog>> streamAllShifts() {
    return _db
        .collection('shifts')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShiftLog.fromFirestore(doc)).toList());
  }
}

