# Staff Document Upload Guide

## Supported Document Types

### 📋 Document Categories

| Document Type | Icon | Purpose | Typical Use |
|--------------|------|---------|-------------|
| **ID Card** | 🪪 | National/Citizen ID | Identity verification, official records |
| **Passport** | 📘 | International passport | International travel, visa processing |
| **Driving License** | 🚗 | Driver's permit | Vehicle authorization, ID verification |
| **Certificate** | 📜 | Educational/Professional certs | Qualifications, training records |
| **Contract** | 📄 | Employment contract | Legal agreements, terms of employment |
| **Resume/CV** | 📝 | Career history | Hiring records, skills documentation |
| **Other** | 📎 | Miscellaneous documents | Any other relevant files |

---

## 📁 Supported File Formats

- **PDF** (.pdf) - Recommended for official documents
- **Images** (.jpg, .jpeg, .png) - For scanned documents
- **Documents** (.doc, .docx) - For editable contracts/resumes

**File Size Limit:** Recommended under 10MB per file

---

## 🔐 Security & Privacy

### Access Control
- ✅ All authenticated users can **view** documents
- ✅ Only **admins** can upload/delete documents
- ✅ Files stored securely in Firebase Storage
- ✅ Each staff member's documents in separate folder

### Storage Location
```
staff_documents/
  ├── {staffId}/
  │   ├── {timestamp}_document1.pdf
  │   ├── {timestamp}_id_card.jpg
  │   └── {timestamp}_contract.pdf
```

### Privacy
- Documents are organized by staff ID
- URLs are secure and require authentication
- Deleted staff members have all documents auto-removed

---

## 📝 How to Upload Documents

### During Staff Creation (Add New Staff)
1. Fill in staff basic information
2. Scroll to "Documents" section
3. Click **"Add Document"** button
4. Select file from your device
5. Choose document type from dropdown
6. Add description (optional)
7. Click **"Add"**
8. Repeat for multiple documents
9. Click **"Save"** to upload all

### For Existing Staff (Edit Staff)
1. Go to Staff Management
2. Find staff member
3. Click **Edit** or go to Details → Edit
4. Scroll to "Documents" section
5. Follow steps 3-9 above

---

## 👁️ How to View Documents

### From Staff Details Screen
1. Open staff member's profile
2. Scroll to "Documents" section
3. See list of all uploaded documents with:
   - Document icon and type
   - File name
   - Description
   - File size
   - Upload date

---

## ⬇️ How to Download Documents

1. Go to Staff Details
2. Find document in list
3. Click **download icon** (⬇️)
4. Document opens in new tab or downloads

**Note:** Requires active internet connection

---

## 🗑️ How to Delete Documents

1. Go to Staff Details
2. Find document to remove
3. Click **delete icon** (🗑️)
4. Confirm deletion
5. Document removed from storage and database

**Warning:** Deletion is permanent and cannot be undone!

---

## 💡 Best Practices

### Naming Files
- Use clear, descriptive names
- Include date if applicable
- Example: `John_Doe_ID_Card_2026.pdf`

### Document Descriptions
Add helpful notes such as:
- "Front side of national ID"
- "Valid until 2028-12-31"
- "Educational certificate - MBA"
- "Employment contract - 2 year term"

### Organization Tips
1. **ID Documents First**
   - Upload ID card and passport early
   - Keep copies up-to-date

2. **Contracts & Agreements**
   - Upload signed employment contract
   - Add renewal dates in description

3. **Certifications**
   - Upload professional certifications
   - Note expiry dates
   - Update when renewed

4. **Regular Reviews**
   - Review documents quarterly
   - Remove outdated files
   - Update expired documents

---

## 📊 Document Count Tracking

The system automatically tracks:
- Total number of documents per staff
- Displayed on staff cards
- Updated in real-time when adding/removing

**Example Display:**
```
Documents (5)
├── ID Card - national_id.pdf
├── Passport - passport_copy.pdf
├── Contract - employment_contract.pdf
├── Certificate - mba_diploma.pdf
└── Resume - cv_latest.pdf
```

---

## ⚠️ Troubleshooting

### Upload Failed
- **Check file size** (keep under 10MB)
- **Verify file format** (PDF, JPG, PNG, DOC, DOCX only)
- **Ensure good internet connection**
- **Confirm admin permissions**

### Can't View Document
- **Check authentication** (must be logged in)
- **Verify document still exists** (not deleted)
- **Try different browser** if issues persist

### Document Not Appearing
- **Wait a moment** for upload to complete
- **Refresh the page**
- **Check if save was completed**
- **Verify in Staff Details screen**

---

## 🎯 Quick Tips

1. ✅ **Always save after uploading** - Documents only save when you click "Save"
2. ✅ **Add descriptions** - Helps identify documents later
3. ✅ **Use PDF for official docs** - Better for printing and archiving
4. ✅ **Scan at good quality** - Minimum 300 DPI for ID cards
5. ✅ **Keep originals safe** - These are copies, secure originals separately
6. ✅ **Update regularly** - Replace expired documents promptly
7. ✅ **Verify uploads** - Check Staff Details after saving

---

## 📞 Need Help?

If you encounter issues:
1. Check you have **admin role**
2. Verify **internet connection**
3. Try **different browser**
4. Clear **browser cache**
5. Contact **system administrator**

---

**Last Updated:** January 25, 2026
