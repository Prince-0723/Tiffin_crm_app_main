import DeliveryStaff from "../models/DeliveryStaff.model.js";
import Customer from "../models/Customer.model.js";
import MealPlan from "../models/Plan.model.js";
import Subscription from "../models/Subscription.model.js";

/**
 * Check if this user has vendor business data (customers, plans, or subscriptions).
 * Used to protect real vendors from abuse: a malicious vendor could add another
 * vendor's phone as customer to hijack their role. We only override vendor→customer
 * when the user has NO business data (likely "accidental vendor").
 *
 * @param {string} userId - User._id
 * @returns {Promise<boolean>} true if they have any customers, plans, or subscriptions
 */
export const hasVendorBusinessData = async (userId) => {
  const [customers, plans, subs] = await Promise.all([
    Customer.countDocuments({ ownerId: userId, isDeleted: { $ne: true } }),
    MealPlan.countDocuments({ ownerId: userId }),
    Subscription.countDocuments({ ownerId: userId }),
  ]);
  return customers > 0 || plans > 0 || subs > 0;
};

/**
 * Resolve role and ownerId for a phone number from existing data.
 * Used at login to know if the person is vendor, customer, or delivery_staff
 * without asking them.
 *
 * Logic:
 * - If phone exists in DeliveryStaff (any vendor added them) → delivery_staff + that vendor's ownerId
 * - Else if phone exists in Customer (any vendor added them) → customer + that vendor's ownerId
 * - Else → vendor (self-registering business owner), ownerId will be set to userId in auth
 *
 * @param {string} phone - 10-digit Indian mobile
 * @returns {Promise<{ role: 'vendor'|'customer'|'delivery_staff', ownerId?: string }>}
 */
export const resolveRoleForPhone = async (phone) => {
  const normalized = String(phone).replace(/\D/g, "").slice(-10);
  if (normalized.length < 10) {
    return { role: "vendor", ownerId: null };
  }

  const [staff, customer] = await Promise.all([
    DeliveryStaff.findOne({
      $or: [{ phone: normalized }, { phone: `0${normalized}` }],
      isActive: true,
    })
      .select("ownerId userId")
      .lean(),
    Customer.findOne({
      $or: [{ phone: normalized }, { phone: `0${normalized}` }],
      isDeleted: { $ne: true },
      status: "active",
    })
      .select("ownerId _id")
      .lean(),
  ]);

  if (staff) {
    return {
      role: "delivery_staff",
      ownerId: staff.ownerId.toString(),
      staffId: staff._id.toString(),
    };
  }
  if (customer) {
    return {
      role: "customer",
      ownerId: customer.ownerId.toString(),
      customerId: customer._id.toString(),
    };
  }

  return { role: "vendor", ownerId: null };
};
