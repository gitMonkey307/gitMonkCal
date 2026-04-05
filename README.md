# 📅 gitMonkCal

A high-density, iOS-native calendar application engineered specifically for untethered sideloading via [SideStore](https://sidestore.io/). 

**gitMonkCal** brings the structural density and power-user layout of Android's Business Calendar 2 to the iOS ecosystem. It strictly adheres to Apple's Human Interface Guidelines while abandoning standard iOS padding limits to maximize screen real estate for heavy schedule management.

---

## ✨ Key Features

* **The 1-14 Day Swipe View:** A dynamic, pagination-locked horizontal timeline. Adjust the slider from 1 to 14 days and watch the grid instantly recalculate with native haptic feedback.
* **High-Density Month Grid:** Edge-to-edge layout with text-wrapped event pills. No more dots—see exactly what is happening at a glance.
* **The "Super Widget":** To conserve free Apple Developer App IDs, gitMonkCal features a single, highly-optimized Agenda widget that dynamically scales across `systemSmall`, `systemMedium`, and `systemLarge` sizes.
* **Native iOS Architecture:** Built entirely with SwiftUI, SF Symbols, and iOS native blur materials (`.ultraThinMaterial`). 
* **Universal Sync:** Powered by `EventKit`. Seamlessly pulls in iCloud, Google, and Exchange calendars natively.

---

## 🛠 Tech Stack & Architecture

* **Language:** Swift 5.9+
* **UI Framework:** SwiftUI
* **Frameworks:** EventKit, WidgetKit, Combine
* **Architecture:** MVVM (Model-View-ViewModel)
* **Deployment Target:** iOS 17.0+

> **Note on App ID Limitations:** Free Apple Developer accounts are limited to 3 active App IDs. gitMonkCal is intentionally designed as a monolithic app with only *one* WidgetKit extension to ensure it plays nicely with SideStore's signing limits. 

---

## 🚀 Installation & Sideloading

Because gitMonkCal relies on untethered sideloading, it is not available on the App Store. You must compile the `.ipa` manually.

### The CI/CD Cloud Build Method (No Mac Required)
If you are on Windows or Linux, you can leverage GitHub Actions to compile the app for you.

1. Fork this repository.
2. Navigate to the **Actions** tab in your forked repo.
3. Click on the **Build iOS App** workflow and select **Run workflow**.
4. Once the macOS cloud server finishes compiling (usually 2-4 minutes), scroll down to the **Artifacts** section of the run.
5. Download the `Calendar-App.zip` file and extract the `gitMonkCal.ipa`.

### Local Build Method (macOS)
1. Open the `.xcodeproj` in Xcode 15+.
2. Set the build destination to **Any iOS Device (arm64)**.
3. Build the project (`Cmd + B`).
4. Locate the compiled `gitMonkCal.app` in your Products folder.
5. Place the `.app` file inside an empty folder named exactly `Payload`.
6. Compress the `Payload` folder into a `.zip` file.
7. Change the extension from `.zip` to `.ipa`.

### Installing via SideStore
1. Transfer `gitMonkCal.ipa` to your iPhone.
2. Open **SideStore**.
3. Navigate to the **My Apps** tab and tap the **+** icon.
4. Select `gitMonkCal.ipa` to sign and install.

---

## 🎨 Design Philosophy
gitMonkCal proves that "dense" does not have to mean "cluttered." By utilizing iOS-native typography (San Francisco) and extremely tight 2pt micro-padding (`DesignSystem.swift`), the app delivers Android-level data density while feeling entirely native to an iPhone 17 Pro.

---

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.
