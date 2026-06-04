import { displayWalletBalance } from "./customerWallet.js";
import { sendNotification } from "../services/inAppNotification.service.js";
import { NOTIFICATION_TYPES } from "./notificationTypes.js";

/**
 * When displayed wallet goes from >0 to ₹0 after a debit, notify the customer (push + in-app).
 */
export async function notifyIfWalletJustHitZero({
  ownerId,
  customerId,
  customerBefore,
  customerAfter,
}) {
  if (!customerBefore || !customerAfter) return;
  const beforeD = displayWalletBalance(customerBefore);
  const afterD = displayWalletBalance(customerAfter);
  if (!(beforeD > 0 && afterD === 0)) return;

  const name = (customerAfter.name || customerBefore.name || "there").trim();
  try {
    await sendNotification({
      customerId,
      ownerId,
      type: NOTIFICATION_TYPES.LOW_BALANCE,
      title: "Wallet balance empty",
      message: `${name ? `${name}, ` : ""}your wallet balance is ₹0. Please add money to continue your tiffin service.`,
      data: {
        walletBalance: 0,
        screen: "wallet",
        reason: "wallet_zero",
      },
    });
  } catch (err) {
    console.error("[notifyIfWalletJustHitZero]", err?.message || err);
  }
}
