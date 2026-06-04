import { verifyAccessToken } from "../services/token.service.js";

/**
 * Initialize the /delivery namespace with JWT auth and room joining.
 * Rooms:
 * - admin:{ownerId}
 * - customer:{customerId}
 * - staff:{staffId}
 * - zone:{zoneId}
 */
export const initDeliverySocket = (io) => {
  const delivery = io.of("/delivery");

  delivery.use((socket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.auth?.accessToken ||
      socket.handshake.headers?.authorization?.replace("Bearer ", "");

    if (!token) {
      return next(new Error("Authentication required"));
    }

    try {
      const decoded = verifyAccessToken(token);
      socket.user = decoded;
      next();
    } catch {
      next(new Error("Invalid or expired token"));
    }
  });

  delivery.on("connection", (socket) => {
    const { userId, role, ownerId, customerId, staffId } = socket.user;

    // Join role-specific rooms using the most specific ID available.
    if (role === "admin" || role === "vendor") socket.join(`admin:${ownerId || userId}`);
    if (role === "customer") socket.join(`customer:${customerId || userId}`);
    if (role === "delivery_boy" || role === "delivery_staff")
      socket.join(`staff:${staffId || userId}`);

    socket.on("join_zone", ({ zoneId }) => {
      if (zoneId) socket.join(`zone:${zoneId}`);
    });

    socket.on("leave_zone", ({ zoneId }) => {
      if (zoneId) socket.leave(`zone:${zoneId}`);
    });

    socket.on("location_update", ({ lat, lng, orderId, customerIdForOrder }) => {
      // Only delivery staff may emit location updates.
      if (role !== "delivery_staff" && role !== "delivery_boy") {
        socket.emit("location_error", { message: "Not authorised to emit location" });
        return;
      }
      if (typeof lat !== "number" || typeof lng !== "number") {
        socket.emit("location_error", { message: "Invalid lat/lng" });
        return;
      }

      const payload = {
        lat,
        lng,
        orderId: orderId ?? null,
        staffId: staffId || userId,
        ...(customerIdForOrder && { customerIdForOrder }),
      };

      // Emit to vendor's admin room so they can track on map.
      delivery.to(`admin:${ownerId || userId}`).emit("location_update", payload);

      // Emit to the customer's room if their customerId is provided (order context).
      if (customerIdForOrder) {
        delivery.to(`customer:${customerIdForOrder}`).emit("location_update", payload);
      }
    });
  });
};

