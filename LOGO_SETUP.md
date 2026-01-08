# Hope Channel Southeast Asia - Logo Setup Guide

## Quick Start

To add your Hope Channel Southeast Asia logo to the app:

### Step 1: Prepare Your Logo
- File format: PNG (with transparent background) or JPG
- Recommended size: 200-400 pixels wide
- File name: **`hope_channel_logo.png`**

### Step 2: Add Logo to Project
1. Navigate to the project folder:
   ```
   /Users/hearyhealdysairin/Documents/Flutter/hc_financial/hc_finannce_report/assets/images/
   ```

2. Copy your logo file to this location

3. Make sure the filename is exactly: **`hope_channel_logo.png`**

### Step 3: Refresh Flutter
Run this command in your terminal:
```bash
cd /Users/hearyhealdysairin/Documents/Flutter/hc_financial/hc_finannce_report
flutter pub get
```

### Step 4: Test
1. Run the app
2. Create a new petty cash report
3. Export to Excel or PDF
4. Check that the logo appears in the header

---

## Current Configuration

### Company Information Set Up:
- **Organization (Parent)**: SOUTHEASTERN ASIA UNION MISSION OF SEVENTH-DAY ADVENTIST FOUNDATION (SEUM)
  - Thai: มูลนิธิสหมิชชั่นเอเชียตะวันออกเฉียงใต้ของเซเว่นธ์เดย์แอ๊ดเวนตีส
  - Address: 195 Moo.3, Muak Lek, Saraburi, 18180 Thailand

- **Company (Reporting Entity)**: Hope Channel Southeast Asia
  - Logo: `assets/images/hope_channel_logo.png`

### Default Settings:
- All new reports automatically use "Hope Channel Southeast Asia" as the company name
- Logo will appear on all exports (Excel & PDF)

---

## Report Header Structure

When you export a report, it will show:

```
┌─────────────────────────────────────────────────┐
│  [HOPE CHANNEL LOGO]                            │
│                                                  │
│  SOUTHEASTERN ASIA UNION MISSION OF             │
│  SEVENTH-DAY ADVENTIST FOUNDATION (SEUM)        │
│  มูลนิธิสหมิชชั่นเอเชียตะวันออกเฉียงใต้ของเซเว่นธ์เดย์แอ๊ดเวนตีส │
│  195 Moo.3, Muak Lek, Saraburi, 18180 Thailand  │
│                                                  │
│         PETTY CASH REPORT                       │
│                                                  │
│  Report Number: PCR-20260106-001                │
│  Company: Hope Channel Southeast Asia           │
│  ...                                            │
└─────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Logo doesn't appear?
1. Check filename is exactly: `hope_channel_logo.png`
2. Check file is in: `assets/images/` folder
3. Run: `flutter pub get`
4. Restart the app

### Want to use a different filename?
Update the constant in `lib/utils/constants.dart`:
```dart
static const String companyLogo = 'assets/images/your_logo_name.png';
```

### Need help?
Contact your development team with:
- Screenshot of the assets folder
- Screenshot of any error messages
- The logo file you're trying to use

---

**Generated with Claude Code** 🤖
