import mongoose from "mongoose";

/**
 * Wallet helpers. `walletBalance` is canonical; `balance` is legacy.
 * During migration either field may hold the real balance; both are decremented
 * together on spend, so the spendable amount is the max of the two (never sum).
 * Display values are never negative (business rule).
 */

/** Parse money from DB/JSON (Decimal128, strings, Mongoose docs). */
export function coerceMoney(v) {
  if (v == null) return 0;
  if (typeof v === "number") return Number.isFinite(v) ? v : 0;
  if (typeof v === "string") {
    const n = parseFloat(v.replace(/,/g, "").trim());
    return Number.isFinite(n) ? n : 0;
  }
  if (typeof v === "object") {
    if (v._bsontype === "Decimal128" || v.constructor?.name === "Decimal128") {
      const n = parseFloat(v.toString());
      return Number.isFinite(n) ? n : 0;
    }
    if (typeof v.toString === "function") {
      const n = parseFloat(String(v).replace(/,/g, ""));
      return Number.isFinite(n) ? n : 0;
    }
  }
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function unwrapCustomer(customer) {
  if (!customer || typeof customer !== "object") return null;
  if (typeof customer.toObject === "function") {
    try {
      return customer.toObject({ flattenMaps: true });
    } catch {
      return customer;
    }
  }
  return customer;
}

export function effectiveWallet(customer) {
  const raw = unwrapCustomer(customer);
  if (!raw) return 0;
  return Math.max(coerceMoney(raw.walletBalance), coerceMoney(raw.balance));
}

/**
 * Authoritative spendable wallet from Mongo (avoids Mongoose/JS coercion bugs).
 * Use for subscription debit checks.
 */
export async function readSpendableWalletFromDb(Customer, customerId, ownerId) {
  const cid =
    customerId instanceof mongoose.Types.ObjectId
      ? customerId
      : new mongoose.Types.ObjectId(String(customerId));
  const oid =
    ownerId instanceof mongoose.Types.ObjectId
      ? ownerId
      : new mongoose.Types.ObjectId(String(ownerId));

  const [row] = await Customer.aggregate([
    {
      $match: {
        _id: cid,
        ownerId: oid,
        isDeleted: { $ne: true },
      },
    },
    {
      $project: {
        eff: {
          $max: [
            {
              $convert: {
                input: "$walletBalance",
                to: "double",
                onError: 0,
                onNull: 0,
              },
            },
            {
              $convert: {
                input: "$balance",
                to: "double",
                onError: 0,
                onNull: 0,
              },
            },
          ],
        },
      },
    },
  ]);

  const n = Number(row?.eff ?? 0);
  return Number.isFinite(n) ? n : 0;
}

/** Shown wallet total — floored at zero. */
export function displayWalletBalance(customer) {
  return Math.max(0, effectiveWallet(customer));
}
