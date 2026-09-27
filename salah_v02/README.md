# Salah v0.3

Global Islamic companion app built with Flutter.

## v0.3
- Prayer times and countdown via AlAdhan
- Ramadan imsak / iftar calendar
- Qibla compass
- Qur'an Arabic text, Turkish translation and audio
- Multiple reciters
- Hadith and dua sections
- Islamic knowledge quiz: 5,820 sourced questions, 10 questions per round, progressive difficulty
- Dhikr counter
- Prayer notifications
- Light / dark themes
- GitHub Releases based in-app Android update check
- Donation UI removed
- Settings audio-Qur'an shortcut removed

## Android update channel
The app checks the latest public GitHub Release on startup. When a newer release contains an APK asset, Salah offers the update and opens the Android package installer after download.

For an Android upgrade to install over the existing app:
- Keep the same applicationId / package name.
- Sign every release APK with the same signing certificate.
- Increase the Flutter build number (Android versionCode).

Version: 0.3.0+3
