import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ble_app/components/google_user.dart';
import 'package:ble_app/components/email_user.dart';
import 'package:ble_app/pages/email_page.dart';
import 'package:ble_app/pages/google_example.dart';
import 'package:ble_app/services/auth_service.dart';
import 'dart:async';

class ProfilePage extends StatefulWidget {
  final GoogleSignInAccount? user;

  const ProfilePage({super.key, this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late GoogleSignInAccount? _currentUser;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user ?? globalGoogleUser;
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Listen to Google Sign In authentication events
    final GoogleSignIn signIn = GoogleSignIn.instance;
    try {
      signIn.initialize().then((_) {
        _authSubscription = signIn.authenticationEvents.listen((event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            setState(() {
              _currentUser = event.user;
              globalGoogleUser = event.user;
            });
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            setState(() {
              _currentUser = null;
              globalGoogleUser = null;
            });
          }
        });
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await GoogleSignIn.instance.disconnect();
    await AuthService.clearAuthState();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildGuestProfile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 40),
            // Guest icon
            CircleAvatar(
              radius: 50,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome Guest',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to access your profile',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 60),
            // Email button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                icon: const Icon(Icons.email_outlined, size: 20),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                  child: Text(
                    'Continue With Email',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Google button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SignInDemo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context, GoogleSignInAccount user) {
    return Center(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _currentUser == null
          ? _buildGuestProfile(context)
          : _buildUserProfile(context, _currentUser!),
    );
  }
}
