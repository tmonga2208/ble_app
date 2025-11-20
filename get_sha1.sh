#!/bin/bash
echo "Getting SHA-1 fingerprint for debug keystore..."
echo ""
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -A 1 "SHA1:" || echo "Error: Could not find debug keystore. Make sure you have run the app at least once."
echo ""
echo "For release builds, use your release keystore:"
echo "keytool -list -v -keystore <path-to-release-keystore> -alias <alias-name>"
