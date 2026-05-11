# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CashbackCounter is a native iOS expense tracking app focused on credit card cashback optimization. Written in Swift using SwiftUI and SwiftData. The developer's first Swift project — most code was AI-generated.

## Build & Run

```bash
# Build (requires Xcode)
xcodebuild -project CashbackCounter.xcodeproj -scheme CashbackCounter -destination 'platform=iOS Simulator,name=iPhone 16'

# Open in Xcode
open CashbackCounter.xcodeproj
```

No test targets exist currently. No CLI linting configured — relies on Xcode's built-in Swift compiler warnings.

## Architecture

**MVVM pattern** with SwiftData persistence:
- **Models/** — SwiftData `@Model` classes: `Transaction`, `CreditCard`, `CardTemplate`, `Income`, `Point`, `PointAdjustment`. Enums: `Category`, `Region`, `PaymentMethod`.
- **Views/** — SwiftUI views using `@Query` for reactive data binding.
- **Components/** — Reusable UI components and service classes.

Key relationships: `CreditCard` → `Transaction` (one-to-many), `Transaction` → `Income` (one-to-many), `CreditCard` ↔ `Point`.

## Key Subsystems

- **Cashback Engine** — Complex rules with base rates, category bonuses, payment method multipliers, separate local/foreign currency caps, monthly/yearly periods.
- **ReceiptParser / OCRService** — Uses Apple FoundationModels (on-device AI) + Vision framework for multi-language receipt scanning (Chinese, Japanese, English).
- **CurrencyService** — Multi-currency support with exchange rates from Frankfurter API, 24-hour cache.
- **CardTemplate** — Pre-configured card templates for major banks with one-click card creation.
- **CameraRecordView** — Custom camera via AVFoundation (not UIImagePickerController).

## Dependencies

- **Swift Package Manager only** (no CocoaPods/Carthage)
- **ZIPFoundation** — ZIP export/import
- **Apple frameworks**: SwiftUI, SwiftData, FoundationModels, Vision, AVFoundation, PDFKit, Charts, AppIntents, Combine, UserNotifications

## Conventions

- All data stored locally via SwiftData — no server/backend
- UI supports light/dark/auto themes and Chinese/English localization
- `Localizable.xcstrings` for all user-facing strings
- Asset catalog (`Assets.xcassets`) contains card images
- Source comments are primarily in Chinese
- GPL-3.0 license
