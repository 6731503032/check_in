// lib/services/auth_service.dart
// Handles Google Sign-In on BOTH web and mobile.
//
// Web:    Uses Firebase signInWithPopup (no native plugin needed)
// Mobile: Uses google_sign_in package → Firebase credential

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const _requiredDomain = 'lamduan.mfu.ac.th';

  /// Returns the signed-in user, or throws a readable error string.
  static Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWeb();
    } else {
      return _signInMobile();
    }
  }

  // ── Web: Firebase popup (no google_sign_in plugin needed) ──────────────
  static Future<User> _signInWeb() async {
    final provider = GoogleAuthProvider();
    // Restrict to university domain
    provider.setCustomParameters({'hd': _requiredDomain});

    final result =
        await FirebaseAuth.instance.signInWithPopup(provider);

    final user = result.user;
    if (user == null) throw 'Sign-in was cancelled.';

    final email = user.email ?? '';
    if (!email.endsWith('@$_requiredDomain')) {
      await FirebaseAuth.instance.signOut();
      throw 'Please use your university email (@$_requiredDomain).';
    }

    return user;
  }

  // ── Mobile: google_sign_in package → Firebase credential ──────────────
  static Future<User> _signInMobile() async {
    final googleUser = await GoogleSignIn(
      hostedDomain: _requiredDomain, // Restricts to university domain
    ).signIn();

    if (googleUser == null) throw 'Sign-in was cancelled.';

    final email = googleUser.email;
    if (!email.endsWith('@$_requiredDomain')) {
      await GoogleSignIn().signOut();
      throw 'Please use your university email (@$_requiredDomain).';
    }

    // ⚠️ Must AWAIT .authentication (this was the original bug!)
    final auth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final result =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user == null) throw 'Firebase sign-in failed.';
    return user;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb) await GoogleSignIn().signOut();
  }
}