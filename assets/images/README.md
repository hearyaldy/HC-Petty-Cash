# Assets Folder - Hope Channel Southeast Asia Logo

## Logo File Requirements

Please add your Hope Channel Southeast Asia logo to this folder with the following specifications:

### File Name
- **Required**: `hope_channel_logo.png`

### Logo Specifications
- **Format**: PNG (recommended for transparency support)
- **Recommended Size**:
  - Width: 200-400 pixels
  - Height: Auto (maintain aspect ratio)
  - Or use your brand standard size
- **Background**: Transparent background preferred
- **Color Mode**: RGB
- **Resolution**: 72-150 DPI (for screen display)

### Supported Formats
While PNG is recommended, you can also use:
- `hope_channel_logo.jpg` (JPEG)
- `hope_channel_logo.svg` (SVG - best for scalability)

### Current Configuration
The app is configured to look for:
```
assets/images/hope_channel_logo.png
```

### After Adding the Logo
1. Place your logo file in this folder (`assets/images/`)
2. Make sure the filename exactly matches: `hope_channel_logo.png`
3. Run `flutter pub get` to ensure assets are recognized
4. The logo will appear on:
   - Excel exports (header section)
   - PDF exports (header section)
   - Future: Login screen and app header

### Testing
After adding the logo:
1. Create a new petty cash report
2. Export to Excel or PDF
3. Verify the logo appears correctly in the header

---

**Note**: If you need to use a different filename or format, update the constant in:
`lib/utils/constants.dart` → `AppConstants.companyLogo`
