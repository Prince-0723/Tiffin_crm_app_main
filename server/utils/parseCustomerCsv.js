function splitCsvLine(line) {
  const out = [];
  let buf = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (ch === "," && !inQuotes) {
      out.push(buf.trim());
      buf = "";
      continue;
    }
    buf += ch;
  }
  out.push(buf.trim());
  return out;
}

/**
 * Parses vendor bulk-import CSV. Expected columns (case-insensitive): name, phone (or mobile), address, zone (or area).
 * @returns {{ rows: Array<{ lineNumber: number, name: string, phone: string, address: string, zone: string }>, errors: string[] }}
 */
export function parseCustomerCsv(csv) {
  const errors = [];
  const lines = String(csv ?? "")
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lines.length < 2) {
    errors.push("CSV must include a header row and at least one data row");
    return { rows: [], errors };
  }

  const headers = splitCsvLine(lines[0]).map((h) => h.toLowerCase());
  const hasName = headers.includes("name");
  const hasPhone = headers.includes("phone") || headers.includes("mobile");
  const hasAddress = headers.includes("address");

  if (!hasName || !hasPhone || !hasAddress) {
    errors.push("Header row must include name, phone (or mobile), and address columns");
    return { rows: [], errors };
  }

  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const cells = splitCsvLine(lines[i]);
    const rowMap = {};
    for (let c = 0; c < headers.length && c < cells.length; c += 1) {
      rowMap[headers[c]] = cells[c].trim();
    }
    rows.push({
      lineNumber: i + 1,
      name: rowMap.name ?? "",
      phone: rowMap.phone ?? rowMap.mobile ?? "",
      address: rowMap.address ?? "",
      zone: rowMap.zone ?? rowMap.area ?? "",
    });
  }

  return { rows, errors };
}
