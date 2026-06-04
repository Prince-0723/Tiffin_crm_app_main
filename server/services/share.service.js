import config from "../config/index.js";

const BASE_URL =
  process.env.BASE_URL || `http://localhost:${config.PORT}/api/v1`;

export const buildInvoiceShareLink = (token) => {
  return `${BASE_URL}/public/invoice/${token}`;
};

export const buildCustomerReportLink = (token) => {
  return `${BASE_URL}/public/customer-report/${token}`;
};

export const buildDeliveryLocationLink = (lat, lng) => {
  return `https://www.google.com/maps?q=${lat},${lng}`;
};

export const buildOrderLink = (orderId) => {
  return `${BASE_URL}/orders/${orderId}`;
};
