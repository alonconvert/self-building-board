#!/usr/bin/env node

/**
 * generate.js — Reads GitHub Issues and injects live ticket data
 * into index.html as a JSON blob.
 *
 * Usage: GITHUB_REPO=owner/repo node generate.js
 * Reads from: GitHub Issues API via `gh` CLI
 * Writes to:  ./index.html
 *
 * Requires: gh CLI authenticated (`gh auth login`)
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const GITHUB_REPO = process.env.GITHUB_REPO;
const INDEX_HTML = path.join(__dirname, 'index.html');

if (!GITHUB_REPO) {
  console.error('ERROR: Set GITHUB_REPO env var (e.g., GITHUB_REPO=alonconvert/my-project)');
  process.exit(1);
}

function ghCommand(args) {
  try {
    return execSync(`gh ${args} --repo ${GITHUB_REPO}`, {
      encoding: 'utf-8',
      timeout: 30000,
    }).trim();
  } catch (e) {
    console.error(`gh command failed: gh ${args}`);
    console.error(e.message);
    return null;
  }
}

function fetchIssues() {
  // Fetch all issues (open and closed) excluding PRDs
  const json = ghCommand(
    'issue list --state all --limit 500 --json number,title,state,labels,body'
  );
  if (!json) return [];

  const issues = JSON.parse(json);

  // Filter out PRD issues
  return issues.filter(
    (i) => !i.title.includes('[SYSTEM PRD]') && !i.title.includes('[MODULE PRD]')
  );
}

function extractModuleFromLabels(labels) {
  for (const label of labels) {
    const match = label.name.match(/^module:(.+)$/);
    if (match) return match[1];
  }
  return 'unassigned';
}

function isEscalated(labels) {
  return labels.some((l) => l.name === 'escalated');
}

function extractBlockedBy(body) {
  if (!body) return [];
  const section = body.split('## Blocked by')[1];
  if (!section) return [];
  const beforeNext = section.split('##')[0];
  const matches = beforeNext.match(/#(\d+)/g);
  return matches ? matches.map((m) => parseInt(m.slice(1))) : [];
}

function computeStats(issues) {
  const modules = {};
  let totalOpen = 0;
  let totalDone = 0;
  let totalEscalated = 0;

  for (const issue of issues) {
    const mod = extractModuleFromLabels(issue.labels);
    if (!modules[mod]) {
      modules[mod] = { done: 0, open: 0, escalated: 0, total: 0, issues: [] };
    }

    const done = issue.state === 'CLOSED';
    const escalated = isEscalated(issue.labels);

    modules[mod].total++;
    if (done) {
      modules[mod].done++;
      totalDone++;
    } else {
      modules[mod].open++;
      totalOpen++;
    }
    if (escalated) {
      modules[mod].escalated++;
      totalEscalated++;
    }

    modules[mod].issues.push({
      number: issue.number,
      title: issue.title,
      done,
      escalated,
      blockedBy: extractBlockedBy(issue.body),
    });
  }

  // Compute percentages
  for (const mod of Object.values(modules)) {
    mod.pct = mod.total > 0 ? Math.round((mod.done / mod.total) * 100) : 0;
  }

  return {
    modules,
    totalOpen,
    totalDone,
    totalEscalated,
    totalTickets: totalOpen + totalDone,
  };
}

function fetchBuildStatus() {
  // Check if any workflow is currently running
  const json = ghCommand(
    'run list --workflow=build-module.yml --limit 1 --json status,name,startedAt,updatedAt,conclusion,headBranch'
  );
  if (!json) return null;

  const runs = JSON.parse(json);
  if (runs.length === 0) return null;

  return runs[0];
}

function injectData(html, stats, buildStatus) {
  const dataJson = JSON.stringify({ ...stats, buildStatus });
  const timestamp = new Date().toISOString();

  html = html.replace(
    /\/\*__LIVE_DATA__\*\/[^;]*;/,
    `/*__LIVE_DATA__*/ window.__DATA__ = ${dataJson}; window.__DATA_TS__ = "${timestamp}";`
  );

  return html;
}

function main() {
  console.log(`Fetching issues from ${GITHUB_REPO}...`);
  const issues = fetchIssues();
  console.log(`  Found ${issues.length} issues`);

  const stats = computeStats(issues);

  for (const [key, mod] of Object.entries(stats.modules)) {
    const escLabel = mod.escalated > 0 ? ` (${mod.escalated} escalated)` : '';
    console.log(`  ${key}: ${mod.done}/${mod.total} done (${mod.pct}%)${escLabel}`);
  }
  console.log(
    `\n  Total: ${stats.totalDone}/${stats.totalTickets} done, ${stats.totalOpen} open, ${stats.totalEscalated} escalated`
  );

  const buildStatus = fetchBuildStatus();
  if (buildStatus) {
    console.log(`\n  Latest build: ${buildStatus.status} (${buildStatus.conclusion || 'in progress'})`);
  }

  console.log('\nInjecting data into index.html...');
  let html = fs.readFileSync(INDEX_HTML, 'utf-8');
  html = injectData(html, stats, buildStatus);
  fs.writeFileSync(INDEX_HTML, html, 'utf-8');

  console.log('Done! Dashboard updated with live data from GitHub.');
}

main();
