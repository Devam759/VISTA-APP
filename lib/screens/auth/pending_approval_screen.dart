import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userProfile;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                size: 100,
                color: Colors.orange,
              ),
              const SizedBox(height: 40),
              Text(
                'Approval Pending',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hello ${user?.name ?? "Student"},\n\nYour registration for ${user?.hostel} has been submitted. Please wait for your Hostel Warden to approve your account and assign a room number.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              OutlinedButton(
                onPressed: () =>
                    Provider.of<AuthProvider>(context, listen: false).signOut(),
                child: const Text('Logout'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).fetchUserProfile(user?.uid ?? ""),
                child: const Text('Check Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
