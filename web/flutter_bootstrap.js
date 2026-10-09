{{flutter_js}}
{{flutter_build_config}}

// Begin as soon as the loader arrives, without waiting for analytics, images,
// or the window load event. App Check is activated by the online controller.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const runner = await engineInitializer.initializeEngine();
      await runner.runApp();
      document.body.classList.add('loaded');
      document.querySelector('.loading-container')?.setAttribute('aria-hidden', 'true');
    } catch (_) {
      const text = document.querySelector('.loading-text');
      if (text) text.textContent = 'Stones could not start. Please reload to try again.';
    }
  }
});
