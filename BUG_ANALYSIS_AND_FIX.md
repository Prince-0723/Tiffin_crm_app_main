# Double Charging Bug Analysis and Fix

## Problem Summary
When an order transitions from `processing` to `delivered`, the wallet is being deducted **twice**:
1. Once when the order enters `processing` state
2. Again when the order moves to `delivered` state

## Root Cause
The `chargeOrderOnce` function in `server/controllers/dailyOrder.controller.js` (lines 175-226) uses a non-atomic check:

```javascript
if (order.isCharged) {
  return { /* already charged response */ };
}
```

**Why this is broken:**
- This check uses an in-memory object property that hasn't been persisted yet
- In concurrent requests (race condition), two requests can both:
  1. Load the same order document from DB (isCharged = false)
  2. Both pass the `if (order.isCharged)` check
  3. Both proceed to deduct wallet
  4. Both attempt to set isCharged = true

## Affected Code Flow
1. **Order moves to processing** → `chargeUnchargedProcessingOrder()` → `chargeOrderOnce()` ✓ charges
   - `order.save()` called, `isCharged` persisted
2. **Concurrent request or delayed delivery → order moves to delivered** → `chargeOrderOnce()` called again
   - Loads fresh order document from DB
   - In-memory check passes (order._id is same object but fresh from DB if race condition)
   - ✗ Charges again (BUG!)

## Solution: Atomic MongoDB Update
Use MongoDB's `findOneAndUpdate` with atomic `$ne` (not equal) filter:

```javascript
// Atomically set isCharged = true ONLY if it's not already true
const updatedOrder = await DailyOrder.findOneAndUpdate(
  { _id: order._id, isCharged: { $ne: true } },  // Filter: only update if isCharged != true
  { $set: { isCharged: true } },                  // Update
  { new: true, session }                          // Return updated doc
);

if (!updatedOrder) {
  // Another request already set isCharged = true
  return { alreadyCharged: true, deducted: 0, ... };
}
// Safe to proceed with deduction
```

## Fix Requirements
1. ✓ Before deducting, atomically set `isCharged=true` in DB using `findOneAndUpdate` with condition `isCharged { $ne: true }`
2. ✓ If `findOneAndUpdate` returns null, return `alreadyCharged: true` immediately (skip deduction)
3. ✓ Remove the `order.markModified("isCharged")` line (DB update handles it)
4. ✓ Keep `order.isCharged = true` at the end to sync in-memory object
5. ✓ Keep all other logic unchanged (minimal, precise fix)

## Impact
- **Before:** Multiple charges possible in race conditions
- **After:** Only one charge guaranteed, even under concurrent requests
- **Backward compatible:** No API changes, no business logic changes
