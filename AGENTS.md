# Kcal Tracker Working Context

## Project

- The app is a SwiftUI + SwiftData iOS app in `KcalTracker.swiftpm`.
- Preserve existing user changes; the worktree may already contain staged and unstaged edits.
- Verify UI/code changes from `KcalTracker.swiftpm` with:
  `xcodebuild -scheme "Calories Tracker" -destination "generic/platform=iOS Simulator" -derivedDataPath /tmp/kcal_tracker_derived CODE_SIGNING_ALLOWED=NO build -quiet`
- The build currently succeeds with pre-existing duplicate `Assets.xcassets` build-file warnings.

## User-facing terminology

- A logged item is always called `Food` / `Foods` in the UI. Keep `Entry` only in internal code and model names.
- A reusable template is always called `Food Preset` / `Food Presets`.
- Creation screens use `Add`; editing screens use `Save`.
- Current titles include `Add Food`, `Add Multiple Foods`, `Edit Food`, `Search Foods`, and `Food Presets`.

## Current UI conventions

- Prefer compact layouts with minimal top controls and no redundant explanatory rows.
- Macro order is Protein, Fat, Carbs.
- Shared row macros display labels without colons or `g`; values hide a trailing `.0` when integral.
- Preset and food rows use kcal on the top-right and portion grams on the bottom-right.
- Food preset nutrition values are per 100g. Calculated totals appear in add/edit forms, not ordinary preset lists.
- `Add Food` has a floating bottom `Add Multiple Foods` capsule instead of a Single/Multiple segmented control.
- `Add Multiple Foods` uses checkbox selection. A selected row replaces its bottom-right default grams with an inline portion input; row geometry must not shift between states.
- Selecting a food preset without a default portion automatically focuses its required portion input.
- The Add Multiple Foods confirmation is a top-right `Add N` button. Total kcal or portion validation appears in the section footer.

## Number input

- Numeric fields use the UIKit-backed controls in `KcalTracker.swiftpm/NumericInput.swift`.
- The custom locale-aware keypad allows only digits and the current locale decimal separator.
- Its bottom action row is `Clear`, `Done`, `Next`; Clear is red. The last field omits Next.
- Do not switch numeric fields back to the system decimal/number keyboard without explicit user direction.
- Keep custom input focus state in ordinary `@State`; native text fields may use `@FocusState`.

## Internal clipboard

- Copied Foods are kept in a newest-first, in-memory history for 10 minutes per item.
- On the main screen, a short paste-button tap pastes directly only when one Food is available; with multiple Foods it opens `ClipboardHistoryView` for checkbox selection. A long press also opens this selector.
- The paste button shows a red history-count badge only when at least two Foods are available.
- Clipboard history rows have a destructive swipe action for immediate removal.
- The selector has a floating red `Clear` capsule that clears all history and dismisses the selector.

## Relevant views

- `AddEntryView.swift`: add one food and launch multiple selection.
- `AddMultipleEntriesView.swift`: batch food-preset selection and portions.
- `AddPresetView.swift` / `PresetSelectionView.swift` / `PresetsView.swift`: food preset creation, selection, and list.
- `EditEntryPortionView.swift`: edit logged food and nutrition.
- `DailyView.swift` / `SearchEntriesView.swift`: main and search row layouts.
- `EntryClipboard.swift` / `ClipboardHistoryView.swift`: in-memory copied-Food history and multi-paste selection.
