# Microsoft 365 Styled Email Setup

This project can now send styled meeting invitations through Microsoft 365 using Microsoft Graph.

## Required Microsoft 365 / Entra setup

Create or use an Entra app registration with:

- `Application` permission: `Mail.Send`
- Admin consent granted
- A client secret

You also need the mailbox/user that should appear as the sender.

## Required Firebase Functions environment variables

Set these values for the Functions runtime:

- `MICROSOFT_TENANT_ID`
- `MICROSOFT_CLIENT_ID`
- `MICROSOFT_CLIENT_SECRET`
- `MICROSOFT_SENDER_USER_ID`

`MICROSOFT_SENDER_USER_ID` can be the sender mailbox UPN/email, for example:

```text
sender@yourdomain.com
```

## Local `.env` example

```text
MICROSOFT_TENANT_ID=your-tenant-id
MICROSOFT_CLIENT_ID=your-app-client-id
MICROSOFT_CLIENT_SECRET=your-app-client-secret
MICROSOFT_SENDER_USER_ID=sender@yourdomain.com
```

## Firebase config example

If you prefer Firebase runtime config instead of `.env`:

```bash
firebase functions:config:set \
  microsoft.tenant_id="your-tenant-id" \
  microsoft.client_id="your-app-client-id" \
  microsoft.client_secret="your-app-client-secret" \
  microsoft.sender_user_id="sender@yourdomain.com"
```

## Deploy

```bash
firebase deploy --only functions
```

## Notes

- The app verifies the signed-in Firebase user before sending.
- Only users with meetings edit access can send invitations.
- The styled email uses the current meeting invitation HTML from the app.
