// Drives the REAL /admin/questions/generate -> generate_review.ejs ->
// /admin/questions/generate/confirm -> /admin/questions flow across many
// batches, visibly, using the actual existing pages and buttons — no separate
// backend orchestration, no hidden fetch() loop. This script just navigates
// the browser through the same steps a human already takes one batch at a
// time, submits the same real forms, and clicks the same real "Generate AI
// Content" button (extended in admin.js to include video) — then repeats for
// the next batch until the target count is reached.
//
// Included on every admin page via partials/head.ejs, deferred after
// admin.js. A no-op everywhere except: (a) always renders the small status
// bar when a run exists in localStorage, (b) auto-drives generate_review.ejs
// and the questions list page ONLY when this run explicitly navigated there
// itself (the `expecting` flag) — so it never hijacks a page the admin opened
// manually while a run happens to be sitting paused/stopped.

(function () {
  var STORAGE_KEY = 'quizo_bulk_ai_run_v2';
  var LOG_CAP = 200;

  function loadRun() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      var run = JSON.parse(raw);
      if (run.version !== 2) return null;
      return run;
    } catch (e) {
      return null;
    }
  }

  function saveRun(run) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(run));
  }

  function clearRun() {
    localStorage.removeItem(STORAGE_KEY);
  }

  function sleep(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  function logEvent(run, level, message) {
    run.log.push({ ts: new Date().toISOString(), level: level, message: message });
    if (run.log.length > LOG_CAP) run.log.splice(0, run.log.length - LOG_CAP);
    saveRun(run);
    renderBar(run);
  }

  // ---- batch math ----

  function splitIntoBatches(total, categoryId, categoryName, maxSize) {
    var batches = [];
    var remaining = total;
    while (remaining > 0) {
      var size = Math.min(remaining, maxSize);
      batches.push({ categoryId: categoryId, categoryName: categoryName, batchSize: size, status: 'pending' });
      remaining -= size;
    }
    return batches;
  }

  function computeBatches(mode, categoryId, targetCount, categories, maxSize) {
    if (mode === 'single') {
      var cat = categories.filter(function (c) { return String(c.id) === String(categoryId); })[0];
      return splitIntoBatches(targetCount, cat.id, cat.name, maxSize);
    }
    var k = categories.length;
    var base = Math.floor(targetCount / k);
    var extra = targetCount % k;
    var all = [];
    categories.forEach(function (c, i) {
      var share = base + (i < extra ? 1 : 0);
      if (share <= 0) return; // targetCount < number of categories — some get none
      all = all.concat(splitIntoBatches(share, c.id, c.name, maxSize));
    });
    return all;
  }

  // ---- navigation: a real hidden form submit — genuine page navigation, not fetch ----

  function submitHiddenForm(action, fields) {
    var form = document.createElement('form');
    form.method = 'post';
    form.action = action;
    Object.keys(fields).forEach(function (name) {
      var input = document.createElement('input');
      input.type = 'hidden';
      input.name = name;
      input.value = fields[name];
      form.appendChild(input);
    });
    document.body.appendChild(form);
    form.submit();
  }

  function goToNextBatch(run) {
    var batch = run.batches[run.currentBatchIndex];
    run.expecting = 'review';
    saveRun(run);
    submitHiddenForm('/admin/questions/generate', {
      category_id: batch.categoryId,
      count: batch.batchSize,
    });
  }

  function startRun(run) {
    saveRun(run);
    goToNextBatch(run);
  }

  // ---- status bar (injected on every page) ----

  function escapeHtml(s) {
    var div = document.createElement('div');
    div.textContent = s || '';
    return div.innerHTML;
  }

  function makeBtn(label, onClick) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = label;
    btn.style.cssText =
      'background:#1e293b;color:#fff;border:1px solid #334155;border-radius:6px;' +
      'padding:4px 12px;font-size:12px;cursor:pointer;';
    btn.addEventListener('click', onClick);
    return btn;
  }

  function renderBar(run) {
    var existing = document.getElementById('bulk-ai-bar');
    var spacer = document.getElementById('bulk-ai-bar-spacer');
    if (!run) {
      if (existing) existing.remove();
      if (spacer) spacer.remove();
      return;
    }
    if (!existing) {
      existing = document.createElement('div');
      existing.id = 'bulk-ai-bar';
      existing.style.cssText =
        'position:fixed;top:0;left:0;right:0;z-index:9999;background:#0f172a;color:#fff;' +
        'padding:10px 20px;font-family:Inter,system-ui,sans-serif;font-size:13px;display:flex;' +
        'align-items:center;justify-content:space-between;gap:16px;box-shadow:0 2px 8px rgba(0,0,0,.25);';
      document.body.insertBefore(existing, document.body.firstChild);
      spacer = document.createElement('div');
      spacer.id = 'bulk-ai-bar-spacer';
      spacer.style.height = '52px';
      document.body.insertBefore(spacer, existing.nextSibling);
    }

    var done = run.batches.filter(function (b) { return b.status === 'done'; }).length;
    var failed = run.batches.filter(function (b) { return b.status === 'failed'; }).length;
    var total = run.batches.length;
    var lastLog = run.log.length ? run.log[run.log.length - 1].message : '';
    var stateLabel =
      run.runState === 'running' ? '● Running' :
        run.runState === 'paused' ? '⏸ Paused' :
          run.runState === 'stopped' ? '■ Stopped' : '✓ Completed';

    var info = document.createElement('div');
    info.innerHTML =
      '<strong>🌙 Bulk AI Questions</strong> — ' + stateLabel + ' — Batch ' +
      Math.min(run.currentBatchIndex + 1, total) + ' / ' + total +
      ' &nbsp;(' + done + ' saved, ' + failed + ' failed)' +
      '<div style="opacity:.65;font-size:11px;margin-top:2px;">' + escapeHtml(lastLog) + '</div>';

    var controls = document.createElement('div');
    controls.style.cssText = 'display:flex;gap:8px;flex-shrink:0;';

    if (run.runState === 'running') {
      controls.appendChild(makeBtn('Pause', function () {
        run.runState = 'paused';
        logEvent(run, 'info', 'Pausing after the current batch finishes…');
      }));
      controls.appendChild(makeBtn('Stop', function () {
        if (!confirm('Stop this run? The current batch will still finish and save — already-saved questions are kept, and you can start a new run for the rest later.')) return;
        run.runState = 'stopped';
        logEvent(run, 'info', 'Stopping after the current batch finishes…');
      }));
    } else if (run.runState === 'paused' || run.runState === 'stopped') {
      controls.appendChild(makeBtn('Resume', function () {
        run.runState = 'running';
        logEvent(run, 'info', 'Resuming…');
        goToNextBatch(run);
      }));
      controls.appendChild(makeBtn('Dismiss', function () {
        if (!confirm('Discard this run? Already-saved questions are not affected.')) return;
        clearRun();
        renderBar(null);
      }));
    } else {
      controls.appendChild(makeBtn('Dismiss', function () {
        clearRun();
        renderBar(null);
      }));
    }

    existing.innerHTML = '';
    existing.appendChild(info);
    existing.appendChild(controls);
  }

  // ---- page-specific auto-driving ----
  // Only acts when `expecting` says THIS run navigated here itself — never
  // hijacks a page the admin opened manually while a run sits paused/stopped.

  async function handleReviewPage(run) {
    if (run.expecting !== 'review') return;
    run.expecting = null;
    saveRun(run);

    if (run.runState !== 'running') {
      logEvent(run, 'warn', 'Landed on the review page but the run is ' + run.runState + ' — not auto-generating. Click Resume to continue.');
      return;
    }

    var batch = run.batches[run.currentBatchIndex];
    logEvent(run, 'info', 'Batch ' + (run.currentBatchIndex + 1) + '/' + run.batches.length + ' (' + batch.categoryName + '): drafted, generating content…');

    await sleep(800); // let the admin see the drafted questions land before the walk starts
    var allBtn = document.getElementById('generate-all-btn');
    if (allBtn) await runGenerateAllContent(allBtn);

    logEvent(run, 'info', 'Content generation done — saving…');
    run.expecting = 'list';
    saveRun(run);
    await sleep(500);
    var form = document.getElementById('review-form');
    if (form) form.submit();
  }

  // generatePreview/generateConfirm's only error paths both re-render the
  // plain generate.ejs form (not generate_review.ejs) with an .alert-error —
  // landing here while `expecting` a 'review' or 'list' page means this
  // batch's draft (or, rarely, its save) failed. Without this, a single
  // transient failure (a Claude rate limit, a dropped connection) would leave
  // the whole run stuck forever with no auto-retry — exactly the case an
  // unattended overnight run most needs to survive.
  function handleDraftFailure(run) {
    if (run.expecting !== 'review' && run.expecting !== 'list') return;
    run.expecting = null;

    var batch = run.batches[run.currentBatchIndex];
    var errorEl = document.querySelector('.alert-error span:last-child');
    var errorMsg = errorEl ? errorEl.textContent.trim() : 'draft/save failed';
    batch.failedAttempts = (batch.failedAttempts || 0) + 1;

    if (batch.failedAttempts >= 3) {
      batch.status = 'failed';
      batch.error = errorMsg;
      run.currentBatchIndex++;
      logEvent(run, 'error', 'Batch ' + (run.currentBatchIndex) + ' failed after 3 attempts (' + errorMsg + ') — moving on to the next batch.');

      if (run.currentBatchIndex >= run.batches.length) {
        run.runState = 'completed';
        var savedBatches = run.batches.filter(function (b) { return b.status === 'done'; }).length;
        logEvent(run, 'info', 'Run complete — ' + savedBatches + ' / ' + run.batches.length + ' batches saved.');
        return;
      }
    } else {
      logEvent(run, 'warn', 'Batch ' + (run.currentBatchIndex + 1) + ' failed (' + errorMsg + ') — retrying, attempt ' + (batch.failedAttempts + 1) + '/3…');
    }

    if (run.runState !== 'running') {
      saveRun(run);
      renderBar(run);
      return; // paused/stopped — wait for Resume rather than retrying immediately
    }
    saveRun(run);
    setTimeout(function () { goToNextBatch(run); }, 5000); // brief backoff so a persistent failure doesn't spin in a tight reload loop
  }

  function handleListPage(run) {
    if (run.expecting !== 'list') return;
    run.expecting = null;

    var batch = run.batches[run.currentBatchIndex];
    batch.status = 'done';
    run.currentBatchIndex++;
    logEvent(run, 'info', 'Batch saved.');

    if (run.currentBatchIndex >= run.batches.length) {
      run.runState = 'completed';
      var savedBatches = run.batches.filter(function (b) { return b.status === 'done'; }).length;
      logEvent(run, 'info', 'Run complete — ' + savedBatches + ' / ' + run.batches.length + ' batches saved.');
      return;
    }
    if (run.runState !== 'running') {
      saveRun(run);
      renderBar(run);
      return; // paused/stopped between batches — wait for Resume
    }
    saveRun(run);
    goToNextBatch(run);
  }

  window.BulkAiRunner = {
    loadRun: loadRun,
    saveRun: saveRun,
    clearRun: clearRun,
    logEvent: logEvent,
    computeBatches: computeBatches,
    startRun: startRun,
    goToNextBatch: goToNextBatch,
    renderBar: renderBar,
  };

  document.addEventListener('DOMContentLoaded', function () {
    // Every authenticated admin page has the sidebar; the login page (which
    // also includes the shared head partial) doesn't — skip entirely there
    // so a stale/active run never shows controls on an unauthenticated page.
    if (!document.querySelector('aside')) return;

    var run = loadRun();
    renderBar(run);
    if (!run) return;

    if (document.getElementById('review-form') && document.getElementById('generate-all-btn')) {
      handleReviewPage(run);
    } else if (window.location.pathname === '/admin/questions') {
      handleListPage(run);
    } else if (document.getElementById('generate-form')) {
      handleDraftFailure(run);
    }
  });
})();
