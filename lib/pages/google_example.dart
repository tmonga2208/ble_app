// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:ble_app/components/google_user.dart';
import 'package:ble_app/pages/connect_page.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// To run this example, replace this value with your client ID, and/or
/// update the relevant configuration files, as described in the README.
String clientId =
    "199330608801-87rgaafc2lvnd11t6a4mat23dpitt8uu.apps.googleusercontent.com";

/// The SignInDemo app.
class SignInDemo extends StatefulWidget {
  ///
  const SignInDemo({super.key});

  @override
  State createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> {
  GoogleSignInAccount? _currentUser;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    final GoogleSignIn signIn = GoogleSignIn.instance;
    unawaited(
      signIn
          .initialize(clientId: clientId)
          .then((_) {
            print('DEBUG: GoogleSignIn initialized successfully');
            signIn.authenticationEvents
                .listen(_handleAuthenticationEvent)
                .onError(_handleAuthenticationError);
            signIn.attemptLightweightAuthentication();
          })
          .catchError((e) {
            print('DEBUG: GoogleSignIn initialization failed: $e');
          }),
    );
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    print('DEBUG: _handleAuthenticationEvent: $event');
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    print('DEBUG: User from event: $user');

    setState(() {
      _currentUser = user;
      globalGoogleUser = user;
      _errorMessage = '';
    });
  }

  Future<void> _handleAuthenticationError(Object e) async {
    setState(() {
      _currentUser = null;
      _errorMessage = e is GoogleSignInException
          ? _errorMessageFromSignInException(e)
          : 'Unknown error: $e';
    });
  }

  Future<void> _handleSignOut() async {
    await GoogleSignIn.instance.disconnect();
  }

  Widget _buildBody() {
    final GoogleSignInAccount? user = _currentUser;
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          if (user != null && mounted)
            ..._buildAuthenticatedWidgets(user)
          else
            ..._buildUnauthenticatedWidgets(),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAuthenticatedWidgets(GoogleSignInAccount user) {
    return <Widget>[
      ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ConnectPage()),
          );
        },
        child: const Text('Connect To Peppy'),
      ),
    ];
  }

  List<Widget> _buildAuthenticatedPage(GoogleSignInAccount user) {
    return <Widget>[
      GoogleUserCircleAvatar(identity: user),
      const SizedBox(height: 16),
      Text(
        user.displayName ?? '',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),
      const Text('Signed in successfully.'),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _handleSignOut, child: const Text('SIGN OUT')),
    ];
  }

  List<Widget> _buildUnauthenticatedWidgets() {
    return <Widget>[
      if (GoogleSignIn.instance.supportsAuthenticate())
        ElevatedButton.icon(
          onPressed: () async {
            try {
              await GoogleSignIn.instance.authenticate();
            } catch (e) {
              _handleAuthenticationError(e);
            }
          },
          icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            child: Text('Continue With Google', style: TextStyle(fontSize: 15)),
          ),
        )
      else
        const Text('This platform does not have a known authentication method'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  String _errorMessageFromSignInException(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Sign in canceled',
      _ => 'GoogleSignInException ${e.code}: ${e.description}',
    };
  }
}
