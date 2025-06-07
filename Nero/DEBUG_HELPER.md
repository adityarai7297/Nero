# Debug Helper for Fresh Install Testing

## How It Works

The app now detects fresh installations by checking a `UserDefaults` key called `hasLaunchedBefore`. When this key doesn't exist (fresh install), the app will:

1. Clear any persisted Supabase auth data from the iOS Keychain
2. Skip the automatic session restore
3. Force users to the sign-in/signup screen
4. Set the flag so subsequent launches work normally

## Testing Fresh Install Behavior

### Method 1: Delete and Reinstall App (Real Test)
1. Delete the app from your device/simulator
2. Build and run again from Xcode
3. App should start at AuthView (sign-in screen)

### Method 2: Reset First Launch Flag (for Quick Testing)
Add this temporary button to your AuthView for testing:

```swift
// Add this to AuthView.swift for testing only
#if DEBUG
Button("Reset First Launch (Debug)") {
    Task {
        await authService.resetFirstLaunch()
    }
}
.foregroundColor(.red)
.padding()
#endif
```

Then:
1. Tap the debug button
2. Force close the app (swipe up and swipe away)
3. Reopen the app - it will behave like a fresh install

### Method 3: Manual UserDefaults Reset
In Xcode console or debug breakpoint:
```swift
UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
```

## Expected Console Output

### Fresh Install:
```
🆕 Fresh app installation detected - clearing any persisted auth data
✅ Cleared any persisted auth data for fresh install
```

### Normal Launch (After First Time):
```
✅ Session restored for user: user@example.com
```

## What This Fixes

- ✅ Users are no longer automatically signed in after deleting/reinstalling the app
- ✅ Fresh installs always start at the AuthView (sign-in/signup screen)
- ✅ Normal app launches still restore sessions properly
- ✅ Sign out still works as expected
- ✅ No impact on existing user experience

## Cleanup After Testing

Remove the debug button from AuthView before releasing to production:
```swift
#if DEBUG
// Remove this entire block
#endif
``` 