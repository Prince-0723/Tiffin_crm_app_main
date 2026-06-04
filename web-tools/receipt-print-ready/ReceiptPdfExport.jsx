/**
 * Optional React version — drop into a Vite/CRA app with:
 *   npm i html2pdf.js
 * Import Poppins in your app root (index.html or CSS).
 *
 * Props match RECEIPT_DATA in index.html.
 */
import { useCallback, useEffect, useRef } from "react";
import html2pdf from "html2pdf.js";

const rupee = (n) =>
  "₹" +
  Number(n).toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

function escapeHtml(s) {
  if (s == null) return "";
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

export default function ReceiptPdfExport({
  ownerName,
  phone,
  city,
  receiptNo,
  date,
  customer,
  sections,
  subtotal,
  tax,
  grandTotal,
  paid,
  balanceDue,
  runningBalance,
}) {
  const rootRef = useRef(null);

  const renderInnerHtml = useCallback(() => {
    const now = new Date();
    const genTs = now.toLocaleString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    let sectionsHtml = "";
    sections.forEach((sec) => {
      const slotSub = sec.items.reduce((s, i) => s + Number(i.total || 0), 0);
      const rows = sec.items
        .map(
          (it) => `
          <tr>
            <td>${escapeHtml(it.name)}</td>
            <td>${escapeHtml(String(it.qty))}</td>
            <td>${escapeHtml(it.unit || "—")}</td>
            <td>${rupee(it.unitPrice)}</td>
            <td>${rupee(it.total)}</td>
          </tr>`
        )
        .join("");
      sectionsHtml += `
        <div class="section-block">
          <p class="section-title">${escapeHtml(sec.title)}</p>
          <div class="items-table-wrap">
            <table class="items-table">
              <thead>
                <tr>
                  <th>Item Name</th>
                  <th>Qty</th>
                  <th>Unit</th>
                  <th>Unit Price</th>
                  <th>Total</th>
                </tr>
              </thead>
              <tbody>
                ${rows}
                <tr class="slot-subtotal-row">
                  <td colspan="5">Slot subtotal: ${rupee(slotSub)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>`;
    });

    return `
      <header class="receipt-header">
        <div class="logo-placeholder" aria-hidden="true"></div>
        <div class="business-block">
          <h1 class="business-name">${escapeHtml(ownerName)}</h1>
          <p class="business-meta">${escapeHtml(phone)}<br/>${escapeHtml(city)}</p>
        </div>
      </header>
      <div class="receipt-meta">
        <div><strong>Receipt No.</strong> ${escapeHtml(receiptNo)}</div>
        <div style="text-align:right"><strong>Date</strong> ${escapeHtml(date)}</div>
      </div>
      <p class="generated-at">Generated: ${escapeHtml(genTs)}</p>
      <div class="bill-to-card">
        <p class="bill-to-label">BILL TO</p>
        <p class="customer-name">${escapeHtml(customer.name)}</p>
        <p class="customer-line">${escapeHtml(customer.phone)} | ${escapeHtml(customer.address)}</p>
        <div class="customer-grid">
          <div><span>Customer Code</span><br/><strong>${escapeHtml(customer.code || "—")}</strong></div>
          <div><span>Subscription</span><br/><strong>${escapeHtml(customer.subscription || "—")}</strong></div>
          <div style="grid-column: 1 / -1"><span>Delivery Slot</span><br/><strong>${escapeHtml(customer.slot || "—")}</strong></div>
        </div>
      </div>
      ${sectionsHtml}
      <div class="summary">
        <div class="summary-row"><span>Subtotal</span><span>${rupee(subtotal)}</span></div>
        <div class="summary-row"><span>Tax</span><span>${rupee(tax)}</span></div>
        <div class="summary-row grand"><span>Grand Total</span><span>${rupee(grandTotal)}</span></div>
        <div class="summary-row"><span>Paid</span><span>${rupee(paid)}</span></div>
        <div class="summary-row"><span>Balance Due</span><span>${rupee(balanceDue)}</span></div>
        <div class="summary-row"><span>Running balance</span><span>${rupee(runningBalance)}</span></div>
      </div>`;
  }, [
    ownerName,
    phone,
    city,
    receiptNo,
    date,
    customer,
    sections,
    subtotal,
    tax,
    grandTotal,
    paid,
    balanceDue,
    runningBalance,
  ]);

  useEffect(() => {
    const el = rootRef.current;
    if (el) el.innerHTML = renderInnerHtml();
  }, [renderInnerHtml]);

  const downloadPdf = useCallback(async () => {
    const el = rootRef.current;
    if (!el) return;
    el.innerHTML = renderInnerHtml();
    const fileName = `Receipt-${(receiptNo || "export").replace(/[^\w.-]+/g, "_")}.pdf`;
    const opt = {
      margin: [10, 10, 10, 10],
      filename: fileName,
      image: { type: "jpeg", quality: 0.98 },
      html2canvas: {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        logging: false,
        backgroundColor: "#ffffff",
      },
      jsPDF: { unit: "mm", format: "a4", orientation: "portrait" },
      pagebreak: { mode: ["avoid-all", "css", "legacy"] },
    };
    await html2pdf().set(opt).from(el).save();
  }, [receiptNo, renderInnerHtml]);

  return (
    <div className="receipt-pdf-export-wrapper">
      <link
        href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700;800&display=swap"
        rel="stylesheet"
      />
      <style>{`
        .receipt-pdf-export-wrapper { font-family: Poppins, system-ui, sans-serif; }
        .receipt-pdf-export-wrapper #receipt-root * {
          color-adjust: exact; -webkit-print-color-adjust: exact; print-color-adjust: exact;
        }
        .receipt-pdf-export-wrapper #receipt-root {
          max-width: 794px; margin: 0 auto; background: #fff; padding: 28px 32px 36px;
          border-radius: 16px; color: #1e1b4b;
        }
        .receipt-header { display:flex; justify-content:space-between; gap:20px; margin-bottom:22px; padding-bottom:18px; border-bottom:2px solid #e9e3ff; }
        .logo-placeholder { width:56px; height:56px; border-radius:14px; background:linear-gradient(135deg,#f5f3ff,#ede9fe); border:2px solid #e9e3ff; }
        .business-block { text-align:right; flex:1; }
        .business-name { font-size:22px; font-weight:800; color:#7c3aed; margin:0 0 6px; }
        .business-meta { font-size:12px; color:#64748b; margin:0; line-height:1.5; }
        .receipt-meta { display:flex; justify-content:space-between; font-size:13px; margin-bottom:8px; }
        .generated-at { font-size:11px; color:#64748b; margin-bottom:20px; }
        .bill-to-card { background:#f5f3ff; border:1px solid #e9e3ff; border-radius:14px; padding:16px 18px; margin-bottom:22px; break-inside:avoid; }
        .bill-to-label { font-size:10px; font-weight:800; letter-spacing:0.12em; color:#7c3aed; margin:0 0 10px; }
        .customer-name { font-size:16px; font-weight:700; margin:0 0 8px; }
        .customer-line { font-size:12px; color:#64748b; margin:0 0 4px; }
        .customer-grid { display:grid; grid-template-columns:1fr 1fr; gap:6px 16px; margin-top:10px; font-size:11px; color:#64748b; }
        .customer-grid strong { color:#1e1b4b; font-weight:600; }
        .section-block { margin-bottom:18px; break-inside:avoid; page-break-inside:avoid; }
        .section-title { background:#7c3aed; color:#fff; font-size:11px; font-weight:800; letter-spacing:0.14em; padding:10px 14px; margin:0; border-radius:8px 8px 0 0; }
        .items-table-wrap { border:1px solid #e9e3ff; border-top:none; border-radius:0 0 10px 10px; overflow:hidden; }
        .items-table { width:100%; border-collapse:collapse; font-size:11px; }
        .items-table thead th { background:#7c3aed; color:#fff; font-weight:700; text-align:left; padding:10px; border:1px solid #6d28d9; }
        .items-table thead th:nth-child(n+2) { text-align:right; }
        .items-table tbody td { padding:9px 10px; border:1px solid #e2e8f0; }
        .items-table tbody tr:nth-child(even) td { background:#faf8ff; }
        .items-table tbody td:nth-child(n+2) { text-align:right; }
        .slot-subtotal-row td { font-weight:700; background:#f1f5f9; border-top:2px solid #e9e3ff; text-align:right; padding-right:12px; }
        .summary { margin-top:20px; border-top:2px solid #e9e3ff; padding-top:14px; font-size:12px; }
        .summary-row { display:flex; justify-content:space-between; padding:6px 0; }
        .summary-row.grand { font-weight:800; font-size:14px; color:#7c3aed; border-top:1px dashed #e9e3ff; margin-top:6px; padding-top:10px; }
      `}</style>
      <button type="button" onClick={downloadPdf} style={{ marginBottom: 16, padding: "12px 22px", borderRadius: 12, border: "none", background: "#7c3aed", color: "#fff", fontWeight: 600, cursor: "pointer" }}>
        Download PDF
      </button>
      <div id="receipt-root" ref={rootRef} className="print-exact" />
    </div>
  );
}
