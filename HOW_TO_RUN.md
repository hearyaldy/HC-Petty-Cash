# How to Run the Petty Cash Manager App

## ✅ Current Status
The app is **BUILT and RUNNING** on your computer!

## 🌐 Access the App

**The app is already running at:**
```
http://localhost:8080
```

### To View It:
1. Open **Google Chrome** (or any web browser)
2. In the address bar, type: `localhost:8080`
3. Press **Enter**

**That's it!** You should see the Petty Cash Manager login screen.

---

## 🔐 Demo Login Accounts

Once the page loads, you'll see 4 demo account cards you can click:

| Role | Email | Password |
|------|-------|----------|
| **Admin** | admin@company.com | admin123 |
| **Manager** | manager@company.com | manager123 |
| **Finance** | finance@company.com | finance123 |
| **User** | user@company.com | user123 |

---

## 📍 What You Should See

### Login Screen:
- Purple "Petty Cash Manager" title
- Wallet icon
- 4 clickable demo account cards
- Email and password input fields
- Blue "Sign In" button

### After Login (Dashboard):
- Welcome message with your name
- Statistics cards (Total Reports, My Reports, etc.)
- Quick action buttons (New Report, View All Reports, etc.)
- Recent reports list

---

## 🔧 If You Don't See Anything

### Troubleshooting:

1. **Make sure you're at the right URL:**
   - Should be: `http://localhost:8080` or just `localhost:8080`
   - NOT: `localhost:54221` or any other port

2. **Hard refresh the page:**
   - Mac: `Cmd + Shift + R`
   - Windows: `Ctrl + Shift + R`

3. **Check browser console for errors:**
   - Press `F12` to open Developer Tools
   - Click "Console" tab
   - Look for any red error messages
   - Share them with me if you see any

4. **Try a different browser:**
   - Safari: Open Safari and go to `http://localhost:8080`
   - Firefox: Same URL

5. **Restart the server:**
   ```bash
   # In terminal, run:
   cd /Users/hearyhealdysairin/Documents/Flutter/hc_financial/hc_finannce_report/build/web
   python3 -m http.server 8080
   ```

---

## 🚀 Features Available

- ✅ Login with role-based access
- ✅ Dashboard with statistics
- ✅ Create new petty cash reports
- ✅ Add transactions
- ✅ Approval workflow
- ✅ Excel export (matches your template)
- ✅ PDF export
- ✅ Automatic calculations

---

## 📂 Project Location

```
/Users/hearyhealdysairin/Documents/Flutter/hc_financial/hc_finannce_report/
```

The built app is in:
```
/Users/hearyhealdysairin/Documents/Flutter/hc_financial/hc_finannce_report/build/web/
```

---

## 🛠️ Development Commands

```bash
# Run in development mode
flutter run -d chrome

# Build for production
flutter build web

# Serve the built app
cd build/web
python3 -m http.server 8080
```

---

## 📞 Need Help?

The server is currently running. You should be able to access it right now at `http://localhost:8080`

If you still can't see it, please:
1. Take a screenshot of your browser window
2. Check what URL is in the address bar
3. Open Developer Tools (F12) and check the Console tab
4. Let me know what you see (or don't see)

---

**Built with Flutter Web** 🚀
**Generated with Claude Code** 🤖
