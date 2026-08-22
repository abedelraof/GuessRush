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
