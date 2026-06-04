import test from "node:test";
import assert from "node:assert/strict";
import { ApiError } from "../class/apiErrorClass.js";
import {
  payLaterConsumptionExposure,
  payLaterEffectiveCreditCap,
  payLaterWouldExceedCreditLimit,
  assertPayLaterAllowsConsumption,
} from "../utils/subscriptionPayLater.js";

test("prepaid: exposure 0, would not exceed", () => {
  const sub = { payLater: false, totalAmount: 1000, remainingBalance: 500, paidAmount: 1000 };
  assert.equal(payLaterConsumptionExposure(sub), 0);
  assert.equal(payLaterWouldExceedCreditLimit(sub, 999), false);
});

test("payLater exposure = consumed - paid (floored at 0)", () => {
  const sub = { payLater: true, totalAmount: 1000, remainingBalance: 700, paidAmount: 0 };
  assert.equal(payLaterConsumptionExposure(sub), 300);
  const sub2 = { payLater: true, totalAmount: 1000, remainingBalance: 700, paidAmount: 300 };
  assert.equal(payLaterConsumptionExposure(sub2), 0);
});

test("payLaterEffectiveCreditCap uses creditLimit when set", () => {
  const a = { payLater: true, totalAmount: 5000, creditLimit: 500 };
  assert.equal(payLaterEffectiveCreditCap(a), 500);
  const b = { payLater: true, totalAmount: 1000 };
  assert.equal(payLaterEffectiveCreditCap(b), 1000);
});

test("payLaterWouldExceedCreditLimit respects cap + epsilon", () => {
  const sub = {
    payLater: true,
    totalAmount: 1000,
    remainingBalance: 800,
    paidAmount: 0,
    creditLimit: 250,
  };
  assert.equal(payLaterConsumptionExposure(sub), 200);
  assert.equal(payLaterWouldExceedCreditLimit(sub, 50), false);
  assert.equal(payLaterWouldExceedCreditLimit(sub, 50.001), true);
});

test("assertPayLaterAllowsConsumption throws ApiError when over cap", () => {
  const sub = {
    payLater: true,
    totalAmount: 100,
    remainingBalance: 0,
    paidAmount: 0,
    creditLimit: 90,
  };
  assert.equal(payLaterConsumptionExposure(sub), 100);
  assert.throws(
    () => assertPayLaterAllowsConsumption(sub, 1),
    (err) => err instanceof ApiError && err.statusCode === 400
  );
});

test("assertPayLaterAllowsConsumption allows when within cap", () => {
  const sub = {
    payLater: true,
    totalAmount: 200,
    remainingBalance: 100,
    paidAmount: 0,
    creditLimit: 120,
  };
  assert.doesNotThrow(() => assertPayLaterAllowsConsumption(sub, 15));
});

test("additional amount 0 is always allowed path", () => {
  const sub = { payLater: true, totalAmount: 10, remainingBalance: 0, paidAmount: 0, creditLimit: 0 };
  assert.equal(payLaterWouldExceedCreditLimit(sub, 0), false);
  assert.doesNotThrow(() => assertPayLaterAllowsConsumption(sub, 0));
});
