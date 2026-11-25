// La app va fija en vertical (orientation: 'portrait'), y Android lo convierte en un requisito de hardware
// (android.hardware.screen.portrait). Google Play lo avisa porque limita los dispositivos donde se instala.
// Lo dejamos como NO obligatorio: la app sigue en vertical, pero Play ya no lo cuenta como restricción.
const { withAndroidManifest } = require('expo/config-plugins');

const FEATURES = ['android.hardware.screen.portrait'];

function markOptional(manifest) {
  const list = manifest['uses-feature'] ?? (manifest['uses-feature'] = []);
  for (const name of FEATURES) {
    const found = list.find((f) => f.$ && f.$['android:name'] === name);
    if (found) found.$['android:required'] = 'false';
    else list.push({ $: { 'android:name': name, 'android:required': 'false' } });
  }
  return manifest;
}

module.exports = function withOptionalPortrait(config) {
  return withAndroidManifest(config, (cfg) => {
    markOptional(cfg.modResults.manifest);
    return cfg;
  });
};
module.exports.markOptional = markOptional;
