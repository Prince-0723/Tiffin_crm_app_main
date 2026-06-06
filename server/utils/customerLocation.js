/**
 * Normalizes customer location from API body into GeoJSON Point + optional address.
 * Supports:
 * - GeoJSON: { type: "Point", coordinates: [lng, lat] }
 * - Flat: { latitude, longitude, address? }
 */
export function resolveCustomerLocationInput(location, fallbackAddress = "") {
  if (!location || typeof location !== "object") return null;

  let lng;
  let lat;
  let addressFromLocation;

  if (Array.isArray(location.coordinates) && location.coordinates.length >= 2) {
    lng = Number(location.coordinates[0]);
    lat = Number(location.coordinates[1]);
    addressFromLocation =
      typeof location.address === "string" ? location.address.trim() : "";
  } else if (location.latitude != null && location.longitude != null) {
    lat = Number(location.latitude);
    lng = Number(location.longitude);
    addressFromLocation =
      typeof location.address === "string" ? location.address.trim() : "";
  } else {
    return null;
  }

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat === 0 && lng === 0) return null;

  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  const resolvedAddress =
    addressFromLocation || String(fallbackAddress || "").trim();

  return {
    geo: {
      type: "Point",
      coordinates: [lng, lat],
    },
    address: resolvedAddress || null,
  };
}

/**
 * Applies resolved location to a create/update payload object (mutates target).
 */
export function applyCustomerLocationToPayload(target, locationInput, fallbackAddress = "") {
  const resolved = resolveCustomerLocationInput(locationInput, fallbackAddress);
  if (!resolved) return false;
  target.location = resolved.geo;
  if (resolved.address) {
    target.address = resolved.address;
  }
  return true;
}
