import fs from "fs/promises";
import path from "path";
import handlebars from "handlebars";

// directory containing .hbs templates
const __dirname = path.dirname(new URL(import.meta.url).pathname);
const templatesDir = path.join(__dirname, "../templates");

// simple in‑memory cache of compiled templates
const cache = new Map();

export async function renderTemplate(name, data = {}) {
  if (cache.has(name)) {
    return cache.get(name)(data);
  }

  const filePath = path.join(templatesDir, `${name}.hbs`);
  const source = await fs.readFile(filePath, "utf8");
  const compiled = handlebars.compile(source);
  cache.set(name, compiled);
  return compiled(data);
}
