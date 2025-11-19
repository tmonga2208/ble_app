import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfilePage extends StatelessWidget {
  final GoogleSignInAccount user;

  const ProfilePage({super.key, required this.user});

  Future<void> _handleSignOut(BuildContext context) async {
    await GoogleSignIn.instance.disconnect();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              GoogleUserCircleAvatar(identity: user),
              const SizedBox(height: 16),
              Text(
                user.displayName ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              const Text('Signed in successfully.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _handleSignOut(context),
                child: const Text('SIGN OUT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
