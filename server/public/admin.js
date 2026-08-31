// "Generate with AI" button on the New question form — drafts one full
// question (via Claude, same call the bulk generate flow uses) for whichever
// category is currently selected, then fills every other field on the form
// in place. Does not touch video_prompt (Claude isn't asked for one — same
// as the bulk review screen, an admin writes that by hand) or category_id
// itself (the admin's own choice, used as the generation input).

document.addEventListener('click', function (e) {
  var btn = e.target.closest('.ai-fill-question-btn');
  if (!btn) return;
  e.preventDefault();
  runAiFillQuestion(btn);
});

async function runAiFillQuestion(btn) {
  var form = btn.closest('form');
  var categoryEl = form.querySelector(btn.dataset.categorySelector);
  var typeEl = btn.dataset.typeSelector ? form.querySelector(btn.dataset.typeSelector) : null;
  var difficultyEl = btn.dataset.difficultySelector ? form.querySelector(btn.dataset.difficultySelector) : null;
  var errorEl = form.querySelector('.ai-fill-error');

  if (errorEl) {
    errorEl.textContent = '';
    errorEl.classList.add('hidden');
  }

  if (!categoryEl || !categoryEl.value) {
    if (errorEl) {
      errorEl.textContent = 'Choose a category first.';
      errorEl.classList.remove('hidden');
    }
    return;
  }

  var originalLabel = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'Generating…';

  try {
    var res = await fetch(btn.dataset.endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        category_id: categoryEl.value,
        type: typeEl ? typeEl.value : '',
        difficulty: difficultyEl ? difficultyEl.value : '',
      }),
    });
    var data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to generate a question.');

    fillQuestionForm(form, data.question);
  } catch (err) {
    if (errorEl) {
      errorEl.textContent = err.message;
      errorEl.classList.remove('hidden');
    } else {
      alert(err.message);
    }
  } finally {
    btn.disabled = false;
    btn.textContent = originalLabel;
  }
}

function fillQuestionForm(form, q) {
  function setValue(name, value) {
    var el = form.querySelector('[name="' + name + '"]');
    if (el && value !== undefined && value !== null) el.value = value;
  }

  var typeEl = form.querySelector('[name="type"]');
  if (typeEl && q.type) {
    typeEl.value = q.type;
    typeEl.dispatchEvent(new Event('change'));
  }
  setValue('difficulty', q.difficulty);
  setValue('timer_seconds', q.timer_seconds);
  setValue('label', q.label);
  setValue('prompt', q.prompt);
  setValue('instruct_text', q.instruct_text);
  setValue('media_placeholder', q.media_placeholder);
  setValue('media_duration', q.media_duration);
  setValue('emojis', q.emojis);
  setValue('video_prompt', q.video_prompt);

  var clues = q.clues || [];
  for (var i = 0; i < 6; i++) {
    setValue('clue_' + i, clues[i] || '');
  }

  var options = q.options || [];
  var optionImagePrompts = q.option_image_prompts || [];
  for (var j = 0; j < 4; j++) {
    setValue('option_' + j, options[j]);
    setValue('option_image_prompt_' + j, optionImagePrompts[j]);
  }
  if (Number.isInteger(q.correct_index)) {
    var radio = form.querySelector('[name="correct_index"][value="' + q.correct_index + '"]');
    if (radio) radio.checked = true;
  }
}

// Shared "Generate Audio" button behavior, used on the AI-review cards and the
// manual question form (both New and Edit). Configured entirely via data-*
// attributes so the same handler works for the different endpoints/DOM shapes:
//
//   data-endpoint            URL to POST { text, instruct_text } to
//   data-scope                selector for the closest ancestor to search within
//   data-text-selector        input holding the question prompt
//   data-instruct-selector    input holding the tone/style instruction
//   data-audio-selector       the <audio> element to point at the result
//   data-error-selector       element to show a failure message in
//   data-hidden-path-selector (optional) hidden input to receive audio_path
//                              (temp-file flow only — absent for the direct/by-id endpoint)

document.addEventListener('click', function (e) {
  var btn = e.target.closest('.generate-audio-btn');
  if (!btn) return;
  e.preventDefault();
  runGenerateAudio(btn);
});

async function runGenerateAudio(btn) {
  var scope = btn.closest(btn.dataset.scope || 'body');
  var textEl = scope.querySelector(btn.dataset.textSelector);
  var instructEl = scope.querySelector(btn.dataset.instructSelector);
  var audioEl = scope.querySelector(btn.dataset.audioSelector);
  var errorEl = btn.dataset.errorSelector ? scope.querySelector(btn.dataset.errorSelector) : null;
  var hiddenPathEl = btn.dataset.hiddenPathSelector ? scope.querySelector(btn.dataset.hiddenPathSelector) : null;

  if (errorEl) {
    errorEl.textContent = '';
    errorEl.classList.add('hidden');
  }

  var originalLabel = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'Generating…';

  try {
    var res = await fetch(btn.dataset.endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: textEl ? textEl.value : '',
        instruct_text: instructEl ? instructEl.value : '',
      }),
    });
    var data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to generate audio.');

    if (audioEl) {
      audioEl.src = data.audio_url;
      audioEl.classList.remove('hidden');
    }
    if (hiddenPathEl && data.audio_path) {
      hiddenPathEl.value = data.audio_path;
    }
  } catch (err) {
    if (errorEl) {
      errorEl.textContent = err.message;
      errorEl.classList.remove('hidden');
    } else {
      alert(err.message);
    }
  } finally {
    btn.disabled = false;
    btn.textContent = originalLabel;
  }
}

// "Generate AI Content" — walks every audio/image/video generate button on the
// review screen, in the page's top-to-bottom order, and runs each one exactly
// like a real click: scrolled into view first so the admin can watch it happen,
// then awaited to completion before moving to the next. Never skips a button
// because of a failure — runGenerateAudio/runGenerateImage/runGenerateVideo
// already catch their own errors internally (they show the inline error span
// and resolve normally), so one failure just leaves that clip/image/video blank
// and the run continues. Video jobs can take minutes each — walking one
// unattended overnight (see bulk-ai-runner.js) is exactly the case that's slow
// but fine to leave running.

document.addEventListener('click', function (e) {
  var btn = e.target.closest('.generate-all-btn');
  if (!btn) return;
  e.preventDefault();
  runGenerateAllContent(btn);
});

function sleep(ms) {
  return new Promise(function (resolve) {
    setTimeout(resolve, ms);
  });
}

async function runGenerateAllContent(triggerBtn) {
  var statusEl = document.getElementById('generate-all-status');
  var targets = Array.prototype.slice.call(
    document.querySelectorAll('.generate-audio-btn, .generate-image-btn, .generate-video-btn')
  );

  if (targets.length === 0) {
    if (statusEl) statusEl.textContent = 'Nothing to generate.';
    return;
  }

  var originalLabel = triggerBtn.textContent;
  triggerBtn.disabled = true;

  for (var i = 0; i < targets.length; i++) {
    var btn = targets[i];
    // A card/option may have been discarded since the run started — nothing to click.
    if (!document.body.contains(btn)) continue;

    var n = i + 1;
    triggerBtn.textContent = 'Generating ' + n + ' / ' + targets.length + '…';
    if (statusEl) statusEl.textContent = n + ' of ' + targets.length;

    btn.scrollIntoView({ behavior: 'smooth', block: 'center' });
    await sleep(450); // let the scroll finish so the admin can actually see which button is next
    btn.classList.add('ring-4', 'ring-brand-400', 'ring-offset-2');

    if (btn.classList.contains('generate-audio-btn')) {
      await runGenerateAudio(btn);
    } else if (btn.classList.contains('generate-video-btn')) {
      await runGenerateVideo(btn);
    } else {
      await runGenerateImage(btn);
    }

    btn.classList.remove('ring-4', 'ring-brand-400', 'ring-offset-2');
  }

  triggerBtn.disabled = false;
  triggerBtn.textContent = originalLabel;
  if (statusEl) statusEl.textContent = 'Done — ' + targets.length + ' generated.';
}

// Shared "Generate Image" button behavior, one per answer option. Same shape as
// the audio handler above but posts { prompt, option_index } and targets an
// <img> instead of an <audio> element. Each option row is its own `data-scope`
// (".option-block") since a question has 4 independent option rows, unlike
// audio which scopes to the whole ".question-card"/form.
//
//   data-endpoint            URL to POST { prompt, option_index } to
//   data-scope                selector for the closest ancestor to search within
//   data-prompt-selector       input holding the image-generation prompt
//   data-image-selector        the <img> element to point at the result
//   data-error-selector        element to show a failure message in
//   data-option-index          which of the 4 options this button belongs to
//   data-hidden-path-selector  (optional) hidden input to receive image_path
//                               (temp-file flow only — absent for the direct/by-id endpoint)

document.addEventListener('click', function (e) {
  var btn = e.target.closest('.generate-image-btn');
  if (!btn) return;
  e.preventDefault();
  runGenerateImage(btn);
});

async function runGenerateImage(btn) {
  var scope = btn.closest(btn.dataset.scope || 'body');
  var promptEl = scope.querySelector(btn.dataset.promptSelector);
  var imageEl = scope.querySelector(btn.dataset.imageSelector);
  var placeholderEl = btn.dataset.placeholderSelector ? scope.querySelector(btn.dataset.placeholderSelector) : null;
  var errorEl = btn.dataset.errorSelector ? scope.querySelector(btn.dataset.errorSelector) : null;
  var hiddenPathEl = btn.dataset.hiddenPathSelector ? scope.querySelector(btn.dataset.hiddenPathSelector) : null;

  if (errorEl) {
    errorEl.textContent = '';
    errorEl.classList.add('hidden');
  }

  var originalLabel = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'Generating…';

  try {
    var res = await fetch(btn.dataset.endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: promptEl ? promptEl.value : '',
        option_index: btn.dataset.optionIndex !== undefined ? Number(btn.dataset.optionIndex) : undefined,
      }),
    });
    var data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to generate image.');

    if (imageEl) {
      imageEl.src = data.image_url;
      imageEl.classList.remove('hidden');
    }
    if (placeholderEl) {
      placeholderEl.classList.add('hidden');
    }
    if (hiddenPathEl && data.image_path) {
      hiddenPathEl.value = data.image_path;
    }
  } catch (err) {
    if (errorEl) {
      errorEl.textContent = err.message;
      errorEl.classList.remove('hidden');
    } else {
      alert(err.message);
    }
  } finally {
    btn.disabled = false;
    btn.textContent = originalLabel;
  }
}

// "Generate Video" button — unlike audio/image, generation runs as an async
// job (can take minutes to tens of minutes), so this submits once and then
// polls the status endpoint on a timer until it reports 'done' or 'failed',
// instead of a single request that waits for the result.
//
//   data-start-endpoint        URL to POST { prompt } to, queues the job
//   data-status-endpoint-base  URL prefix — job id is appended to poll it
//   data-scope                 selector for the closest ancestor to search within
//   data-prompt-selector       textarea holding the video-generation prompt
//   data-video-selector        the <video> element to point at the result
//   data-error-selector        element to show a failure message in
//   data-hidden-path-selector  (optional) hidden input to receive video_path
//                               (temp-file flow only — absent for the direct/by-id endpoint)

document.addEventListener('click', function (e) {
  var btn = e.target.closest('.generate-video-btn');
  if (!btn) return;
  e.preventDefault();
  runGenerateVideo(btn);
});

async function runGenerateVideo(btn) {
  var scope = btn.closest(btn.dataset.scope || 'body');
  var promptEl = scope.querySelector(btn.dataset.promptSelector);
  var videoEl = scope.querySelector(btn.dataset.videoSelector);
  var errorEl = btn.dataset.errorSelector ? scope.querySelector(btn.dataset.errorSelector) : null;
  var hiddenPathEl = btn.dataset.hiddenPathSelector ? scope.querySelector(btn.dataset.hiddenPathSelector) : null;

  if (errorEl) {
    errorEl.textContent = '';
    errorEl.classList.add('hidden');
  }

  var originalLabel = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'Queuing…';

  try {
    var startRes = await fetch(btn.dataset.startEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: promptEl ? promptEl.value : '' }),
    });
    var startData = await startRes.json();
    if (!startRes.ok) throw new Error(startData.error || 'Failed to queue video generation.');

    var data;
    while (true) {
      await sleep(3000);
      var pollRes = await fetch(btn.dataset.statusEndpointBase + startData.job_id);
      data = await pollRes.json();
      if (!pollRes.ok) throw new Error(data.error || 'Failed to generate video.');
      if (data.status === 'done') break;
      btn.textContent =
        data.status === 'queued' && data.queue_position
          ? 'Queued (#' + data.queue_position + ')…'
          : 'Generating… (can take a while)';
    }

    if (videoEl) {
      videoEl.src = data.video_url;
      videoEl.classList.remove('hidden');
    }
    if (hiddenPathEl && data.video_path) {
      hiddenPathEl.value = data.video_path;
    }
  } catch (err) {
    if (errorEl) {
      errorEl.textContent = err.message;
      errorEl.classList.remove('hidden');
    } else {
      alert(err.message);
    }
  } finally {
    btn.disabled = false;
    btn.textContent = originalLabel;
  }
}
