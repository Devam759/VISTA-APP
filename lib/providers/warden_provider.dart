import 'dart:async';
import 'package:flutter/material.dart';
import '../models/vista_user.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';
import '../models/short_stay_model.dart';
import '../services/firebase_service.dart';

class WardenProvider with ChangeNotifier {
  final FirebaseService _fs = FirebaseService();
  final String initialHostel;
  final String role;
  String? _currentHostelFilter;

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

  WardenProvider(this.initialHostel, {this.role = 'Warden'}) {
    _currentHostelFilter = initialHostel.isEmpty || initialHostel == 'All' ? 'All' : initialHostel;
    _initStreams();
  }

  // Getters
  String? get currentHostelFilter => _currentHostelFilter;
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

  void updateHostelFilter(String? newFilter) {
    if (_currentHostelFilter == newFilter) return;
    _currentHostelFilter = newFilter;
    debugPrint('[WardenProvider] Filter changed to: $newFilter');
    _clearSubscriptions();
    _initStreams();
    notifyListeners();
  }

  void setHostelFilter(String? newFilter) => updateHostelFilter(newFilter);

  void _clearSubscriptions() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _initStreams() {
    final filter = _currentHostelFilter; // null means 'All'
    debugPrint('[WardenProvider] Initializing streams with filter: $filter');

    // 1. Pending Registrations
    _subscriptions.add(
      _fs.getPendingRegistrations(filter).listen((list) {
        if (list.length > _pendingRegistrations.length) {
          _hasNewRegistrations = true;
        }
        _pendingRegistrations = list;
        notifyListeners();
      }),
    );

    // 2. Pending Leaves
    _subscriptions.add(
      _fs.getPendingLeaves(filter).listen((list) {
        if (list.length > _pendingLeaves.length) {
          _hasNewLeaves = true;
        }
        _pendingLeaves = list;
        notifyListeners();
      }),
    );

    // 3. Complaints
    _subscriptions.add(
      _fs.getComplaintsForRole(role, filter).listen((list) {
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
      _fs.getPendingShortStays(filter).listen((list) {
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
      _fs.getHostelStudents(filter).listen((list) {
        _students = list;
        _isLoading = false;
        notifyListeners();
      }),
    );

    // 6. All Leaves
    _subscriptions.add(
      _fs.getHostelLeaves(filter).listen((list) {
        _leaves = list;
        notifyListeners();
      }),
    );

    // 7. All Complaints
    _subscriptions.add(
      _fs.getComplaintsForRole(role, filter).listen((list) {
        _complaints = list;
        notifyListeners();
      }),
    );

    // 8. All Short Stays
    _subscriptions.add(
      _fs.getHostelShortStays(filter).listen((list) {
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
    _clearSubscriptions();
    super.dispose();
  }
}
