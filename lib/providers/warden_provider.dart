import 'dart:async';
import 'package:flutter/material.dart';
import '../models/vista_user.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';
import '../models/short_stay_model.dart';
import '../services/firebase_service.dart';

class WardenProvider with ChangeNotifier {
  final FirebaseService _fs = FirebaseService();
  final String hostel;

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Data for Badge Counts and Quick Access
  List<VistaUser> _pendingRegistrations = [];
  List<LeaveRequest> _pendingLeaves = [];
  List<Complaint> _pendingComplaints = [];
  List<ShortStayRequest> _pendingShortStays = [];

  // Data for main lists
  List<VistaUser> _students = [];
  List<LeaveRequest> _leaves = [];
  List<Complaint> _complaints = [];
  List<ShortStayRequest> _shortStays = [];
  bool _isLoading = false;

  // Markers
  bool _hasNewRegistrations = false;
  bool _hasNewLeaves = false;
  bool _hasNewComplaints = false;
  bool _hasNewShortStays = false;

  WardenProvider(this.hostel) {
    _initStreams();
  }

  // Getters
  bool get hasNewRegistrations => _hasNewRegistrations;
  bool get hasNewLeaves => _hasNewLeaves;
  bool get hasNewComplaints => _hasNewComplaints;
  bool get hasNewShortStays => _hasNewShortStays;

  List<VistaUser> get pendingRegistrations => _pendingRegistrations;
  List<LeaveRequest> get pendingLeaves => _pendingLeaves;
  List<Complaint> get pendingComplaints => _pendingComplaints;
  List<ShortStayRequest> get pendingShortStays => _pendingShortStays;
  
  List<VistaUser> get students => _students;
  List<LeaveRequest> get leaves => _leaves;
  List<Complaint> get complaints => _complaints;
  List<ShortStayRequest> get shortStays => _shortStays;
  bool get isLoading => _isLoading;

  void _initStreams() {
    debugPrint('[WardenProvider] Initializing streams for hostel: $hostel');

    // 1. Pending Registrations
    _subscriptions.add(
      _fs.getPendingRegistrations(hostel).listen((list) {
        if (list.length > _pendingRegistrations.length) {
          _hasNewRegistrations = true;
        }
        _pendingRegistrations = list;
        notifyListeners();
      }),
    );

    // 2. Pending Leaves
    _subscriptions.add(
      _fs.getPendingLeaves(hostel).listen((list) {
        if (list.length > _pendingLeaves.length) {
          _hasNewLeaves = true;
        }
        _pendingLeaves = list;
        notifyListeners();
      }),
    );

    // 3. Complaints
    _subscriptions.add(
      _fs.getComplaintsForRole('Warden', hostel).listen((list) {
        final pending = list.where((c) => c.status == 'Pending').toList();
        if (pending.length > _pendingComplaints.length) {
          _hasNewComplaints = true;
        }
        _pendingComplaints = pending;
        notifyListeners();
      }),
    );

    // 4. Short Stays
    _subscriptions.add(
      _fs.getPendingShortStays(hostel).listen((list) {
        if (list.length > _pendingShortStays.length) {
          _hasNewShortStays = true;
        }
        _pendingShortStays = list;
        notifyListeners();
      }),
    );
    
    // 5. Students
    _isLoading = true;
    _subscriptions.add(
      _fs.getHostelStudents(hostel).listen((list) {
        _students = list;
        _isLoading = false;
        notifyListeners();
      }),
    );

    // 6. All Leaves
    _subscriptions.add(
      _fs.getHostelLeaves(hostel).listen((list) {
        _leaves = list;
        notifyListeners();
      }),
    );

    // 7. All Complaints (Already handled by role/hostel in stream 3, but let's separate for clarity if needed)
    // Actually stream 3 was filtering for 'Pending'. We need full history too.
    _subscriptions.add(
      _fs.getComplaintsForRole('Warden', hostel).listen((list) {
        _complaints = list;
        notifyListeners();
      }),
    );

    // 8. All Short Stays
    _subscriptions.add(
      _fs.getHostelShortStays(hostel).listen((list) {
        _shortStays = list;
        notifyListeners();
      }),
    );
  }

  void clearMarker(int index) {
    bool changed = false;
    if (index == 0 && _hasNewRegistrations) {
      _hasNewRegistrations = false;
      changed = true;
    }
    if (index == 2 && _hasNewLeaves) {
      _hasNewLeaves = false;
      changed = true;
    }
    if (index == 3 && _hasNewComplaints) {
      _hasNewComplaints = false;
      changed = true;
    }
    if (index == 4 && _hasNewShortStays) {
      _hasNewShortStays = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('[WardenProvider] Disposing streams');
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
