# 📅 gitMonkCal

A **fully featured** iOS-native clone of Android's Business Calendar 2, optimized for high-density power-user layouts and untethered sideloading via [SideStore](https://sidestore.io/).

**Identical visual structure** to BC2: Month grid, 1-14 day timeline, Day/Week/Agenda/Tasks views, dense event pills, customizable toolbar slider, native recurrence/alarms/templates, calendar toggles, search, themes, core hours.

Uses EventKit + Reminders for events/tasks sync (iCloud/Google/Exchange).

## ✨ Core BC2 Features Implemented
- **Views**: Month (dense grid), Multi-Day Timeline (1-14 days haptic slider), Day (vertical timeline), Week (7-day), Agenda, Tasks (Reminders), Settings.
- **Editing**: Title/location/notes/alarms (multi), all-day, recurrence (daily/weekly/monthly/yearly), calendar select.
- **Customizations**: Calendar visibility, core hours slider (timeline), padding density, theme opacity/colors.
- **Search/Filter**: Global search across events/tasks.
- **Widgets**: Dense Agenda (small/medium/large, auto-scales).
- **Sync**: Native EventKit/Reminders, auto-refresh on changes.
- **UI**: Edge-to-edge, 2pt micro-padding, SF typography, ultraThinMaterial toolbars, haptics.

## 🛠 Tech Stack
- SwiftUI, EventKit, WidgetKit, Combine.
- MVVM, iOS 17+.
- Tuist for Xcode project.

## 🚀 Installation
1. `tuist generate`
2. Build for device (`Cmd+B`).
3. Payload -> .ipa -> SideStore install.
Or GitHub Actions artifact.

## 📱 Screenshots
[Month](screenshots/month.png) [Timeline](screenshots/timeline.png) etc. (add your own)

MIT License.
