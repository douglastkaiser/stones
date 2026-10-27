{{flutter_js}}
{{flutter_build_config}}

// Keep the HTML loader until Flutter's first initialized frame is rasterized.
try {
  Promise.resolve(_flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const runner = await engineInitializer.initializeEngine();
        await runner.runApp();
      } catch (_) {
        window.stonesStartup?.fail();
      }
    }
  })).catch(() => window.stonesStartup?.fail());
} catch (_) {
  window.stonesStartup?.fail();
}
