# Petty Cash Voucher - Complete Details

## Overview
A Petty Cash Voucher is a document that records a single expense/transaction from petty cash. Each transaction can be exported as an individual voucher for record-keeping and approval.

---

## Voucher Structure

### 📋 HEADER SECTION
```
┌─────────────────────────────────────────────────────────────┐
│                                                               │
│  SOUTHEASTERN ASIA UNION MISSION OF SEVENTH-DAY ADVENTIST    │
│  FOUNDATION (SEUM)                                            │
│  มูลนิธิสหมิชชั่นเอเชียตะวันออกเฉียงใต้ของเซเว่นธ์เดย์แอ๊ดเวนตีส  │
│  195 Moo.3, Muak Lek, Saraburi, 18180 Thailand               │
│                                                               │
│  ═══════════════════════════════════════════════════════════ │
│                                                               │
│              PETTY CASH VOUCHER                               │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Contains:**
- Organization name (English)
- Organization name (Thai)
- Organization address
- Document title: "PETTY CASH VOUCHER"

---

### 📄 VOUCHER DETAILS SECTION
```
┌─────────────────┬─────────────────┬─────────────────┐
│ Voucher No:     │ Date:           │ Company:        │
│ RCP-2024-001    │ 06/01/2026      │ Hope Channel    │
│                 │                 │ Southeast Asia  │
│ Report No:      │ Department:     │ Status:         │
│ PCR-20260106-01 │ Finance         │ Approved        │
└─────────────────┴─────────────────┴─────────────────┘
```

**Fields:**
1. **Voucher Number** - Unique receipt/voucher identifier (e.g., RCP-2024-001)
2. **Report Number** - Associated petty cash report reference
3. **Date** - Transaction date (dd/mm/yyyy format)
4. **Department** - Department making the expense
5. **Company** - Hope Channel Southeast Asia (default)
6. **Status** - Transaction status (Draft, Pending, Approved, Rejected, Processed)

---

### 💰 TRANSACTION DETAILS SECTION
```
┌─────────────────────────────────────────────────────────────┐
│  Paid To:              John Doe                              │
│  Amount:               $250.00                               │
│  Description:          Office supplies purchase              │
│  Category:             Office Expenses                       │
│  Payment Method:       Cash                                  │
│  Receipt Number:       RCP-2024-001                          │
└─────────────────────────────────────────────────────────────┘
```

**Fields:**
1. **Paid To** - Name of person/vendor who received the money
2. **Amount** - Transaction amount in dollars (numerical format)
3. **Description** - Detailed description of the expense
4. **Category** - Expense category:
   - Office Expenses
   - Travel
   - Meals & Entertainment
   - Utilities
   - Maintenance
   - Supplies
   - Other
5. **Payment Method** - How payment was made:
   - Cash
   - Card
   - Bank Transfer
   - Other
6. **Receipt Number** - Physical receipt/invoice reference number

---

### 📝 AMOUNT IN WORDS SECTION
```
┌─────────────────────────────────────────────────────────────┐
│  Amount in Words: TWO HUNDRED FIFTY DOLLARS                  │
└─────────────────────────────────────────────────────────────┘
```

**Purpose:**
- Prevents fraud and alteration
- Clearly spells out the exact amount
- Includes cents if applicable (e.g., "and Fifty Cents")

---

### ✍️ AUTHORIZATION SECTION
```
┌─────────────────────────────────────────────────────────────┐
│                      AUTHORIZATION                            │
│                                                               │
│  ┌──────────────────┐           ┌──────────────────┐        │
│  │ Requested By     │           │ Approved By      │        │
│  │                  │           │                  │        │
│  │ John Doe         │           │ Jane Smith       │        │
│  │ _______________  │           │ _______________  │        │
│  │ Signature        │           │ Signature        │        │
│  │                  │           │                  │        │
│  │ 06/01/2026       │           │ 06/01/2026       │        │
│  │ _______________  │           │ _______________  │        │
│  │ Date             │           │ Date             │        │
│  └──────────────────┘           └──────────────────┘        │
│                                                               │
│  ┌──────────────────┐           ┌──────────────────┐        │
│  │ Received By      │           │ Verified By      │        │
│  │                  │           │ (Finance)        │        │
│  │ _______________  │           │ _______________  │        │
│  │ _______________  │           │ _______________  │        │
│  │ Signature        │           │ Signature        │        │
│  │                  │           │                  │        │
│  │ _______________  │           │ _______________  │        │
│  │ _______________  │           │ _______________  │        │
│  │ Date             │           │ Date             │        │
│  └──────────────────┘           └──────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

**Four Signature Boxes:**

1. **Requested By**
   - Person who initiated the expense
   - Auto-filled with requestor name from system
   - Signature line
   - Date line

2. **Approved By**
   - Manager/supervisor who approved the expense
   - Auto-filled if approved in system
   - Signature line
   - Date line

3. **Received By**
   - Person who physically received the cash/reimbursement
   - Blank for manual completion
   - Signature line
   - Date line

4. **Verified By (Finance)**
   - Finance department verification
   - Blank for manual completion
   - Signature line
   - Date line

---

### 📌 FOOTER SECTION
```
┌─────────────────────────────────────────────────────────────┐
│ For Office Use Only                                           │
│ Voucher ID: txn_1234567890          Printed: 06/01/2026     │
└─────────────────────────────────────────────────────────────┘
```

**Contains:**
- "For Office Use Only" label
- Internal transaction ID
- Print date/time
- System reference information

---

## How to Generate Vouchers

### Method 1: From Report Detail Screen
1. Open any petty cash report
2. View the transaction list
3. Each transaction has a "**Voucher**" button
4. Click the button to export that transaction as a voucher
5. PDF is saved to your downloads folder

### Method 2: From Approvals Screen
1. Open pending approvals
2. Expand any transaction
3. After approval, export as voucher for records

---

## Use Cases

### 1. **Approval Workflow**
- Print voucher for manager signature
- Physical approval on paper
- File for audit trail

### 2. **Reimbursement**
- Employee submits expense
- Print voucher with details
- Attach physical receipt
- Get approval signatures
- Process reimbursement

### 3. **Audit Trail**
- Each transaction has individual voucher
- Complete documentation
- Signature verification
- Easy to file and retrieve

### 4. **Record Keeping**
- Print vouchers for completed transactions
- File chronologically or by department
- Permanent physical record
- Backup to digital reports

---

## File Naming Convention

Exported vouchers are saved as:
```
Voucher_[Receipt Number]_[Timestamp].pdf
```

**Example:**
```
Voucher_RCP-2024-001_1704531234567.pdf
```

---

## Key Features

✅ **Professional Format** - Clean, organized layout
✅ **Bilingual** - English and Thai organization name
✅ **Complete Information** - All transaction details included
✅ **Amount in Words** - Prevents fraud
✅ **Multiple Signatures** - Full approval chain
✅ **Unique Identification** - Voucher number and transaction ID
✅ **Audit Ready** - Includes all required fields
✅ **Print Friendly** - Optimized for A4 paper

---

## Voucher vs Report

| Feature | Petty Cash Voucher | Petty Cash Report |
|---------|-------------------|-------------------|
| Scope | Single transaction | Multiple transactions |
| Use | Individual approval/reimbursement | Summary/overview |
| Signatures | 4 signature boxes | Summary only |
| Detail Level | Very detailed | Summarized |
| When to Use | Per-transaction basis | Period summary |
| File Size | 1 page | Multiple pages |

---

## Security Features

1. **Amount in Words** - Prevents number alteration
2. **Unique Voucher ID** - Prevents duplication
3. **Multiple Signatures** - Authorization trail
4. **Transaction ID** - System reference
5. **Print Date** - Timestamp for audit
6. **Status Indicator** - Shows approval status

---

## Best Practices

### ✅ Do's
- Print vouchers immediately after transactions
- Get all required signatures
- Attach physical receipts to vouchers
- File vouchers chronologically
- Keep digital and physical copies
- Review vouchers before signing
- Verify amounts match receipts

### ❌ Don'ts
- Don't sign blank vouchers
- Don't alter printed amounts
- Don't lose original receipts
- Don't skip signature lines
- Don't approve without verification
- Don't mix departments in filing

---

## Support

For questions about petty cash vouchers:
- Check transaction status in app
- Verify all fields are filled
- Ensure signatures are obtained
- Contact finance department for approval

---

**Generated with Claude Code** 🤖
**Hope Channel Southeast Asia - Petty Cash Management System**
