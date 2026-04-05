#!/usr/bin/env node

/**
 * generate.js — Reads kanban/*.md files and embeds live ticket data
 * into index.html as a JSON blob.
 *
 * Usage: node generate.js
 * Reads from: PROJECT_ROOT/docs/kanban/ (set PROJECT_ROOT env var, or defaults to ../project)
 * Writes to:  ./index.html
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = process.env.PROJECT_ROOT
  ? path.resolve(process.env.PROJECT_ROOT)
  : path.resolve(__dirname, '../project');
const KANBAN_DIR = path.join(PROJECT_ROOT, 'docs/kanban');
const INDEX_HTML = path.join(__dirname, 'index.html');

// Parse a single kanban markdown file
function parseKanbanFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const phases = [];
  let currentPhase = null;

  for (const line of lines) {
    if (/^#\s+[^#]/.test(line)) continue;

    const phaseMatch = line.match(/^#{2,3}\s+(.+)/);
    if (phaseMatch) {
      if (currentPhase) phases.push(currentPhase);
      currentPhase = { title: phaseMatch[1].trim(), tickets: [] };
      continue;
    }

    // Match ticket rows: | ID | description | status | ... |
    const ticketMatch = line.match(/^\|\s*((?:[A-Z]+-\d+|(?:SCHED|DS-R)[-\d]+))\s*\|\s*([^|]+)/);
    if (ticketMatch && currentPhase) {
      const id = ticketMatch[1];
      const title = ticketMatch[2].trim();
      const done = /\u2705\s*Done/i.test(line);
      currentPhase.tickets.push({ id, title, done });
    }
  }
  if (currentPhase) phases.push(currentPhase);

  return phases.filter(p => p.tickets.length > 0);
}

function parseAllKanbans() {
  const files = fs.readdirSync(KANBAN_DIR).filter(f => f.endsWith('.md'));
  const result = {};
  for (const file of files) {
    const key = file.replace('.md', '');
    result[key] = parseKanbanFile(path.join(KANBAN_DIR, file));
  }
  return result;
}

function computeStats(kanbanData) {
  const modules = {};
  let totalOpen = 0;
  let totalDone = 0;

  for (const [key, phases] of Object.entries(kanbanData)) {
    let done = 0, total = 0;
    for (const phase of phases) {
      for (const t of phase.tickets) {
        total++;
        if (t.done) done++;
      }
    }
    const open = total - done;
    totalOpen += open;
    totalDone += done;
    modules[key] = { done, total, open, pct: total > 0 ? Math.round((done / total) * 100) : 0, phases };
  }

  return { modules, totalOpen, totalDone, totalTickets: totalOpen + totalDone };
}

function injectData(html, stats) {
  const dataJson = JSON.stringify(stats);
  const timestamp = new Date().toISOString();

  html = html.replace(
    /\/\*__LIVE_DATA__\*\/[^;]*;/,
    `/*__LIVE_DATA__*/ window.__DATA__ = ${dataJson}; window.__DATA_TS__ = "${timestamp}";`
  );

  return html;
}

function main() {
  if (!fs.existsSync(KANBAN_DIR)) {
    console.error(`Kanban directory not found: ${KANBAN_DIR}`);
    process.exit(1);
  }

  console.log('Parsing kanban files...');
  const kanbanData = parseAllKanbans();
  const stats = computeStats(kanbanData);

  for (const [key, mod] of Object.entries(stats.modules)) {
    console.log(`  ${key}: ${mod.done}/${mod.total} done (${mod.pct}%)`);
  }
  console.log(`\n  Total: ${stats.totalDone}/${stats.totalTickets} done, ${stats.totalOpen} open`);

  console.log('\nInjecting data into index.html...');
  let html = fs.readFileSync(INDEX_HTML, 'utf-8');
  html = injectData(html, stats);
  fs.writeFileSync(INDEX_HTML, html, 'utf-8');

  console.log('Done! Dashboard updated with live data.');
}

main();
