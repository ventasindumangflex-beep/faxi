// Evita que el daemon de Gradle muera por falta de memoria en los servidores de EAS
// ("Could not receive a message from the daemon").
// - Sube la memoria de Gradle para todos los builds.
// - En el build de desarrollo (APP_VARIANT=development) compila solo arm64-v8a (teléfonos Android actuales).
const { withGradleProperties } = require('expo/config-plugins');

module.exports = function withGradleMemory(config) {
  return withGradleProperties(config, (cfg) => {
    const set = (key, value) => {
      cfg.modResults = cfg.modResults.filter((item) => !(item.type === 'property' && item.key === key));
      cfg.modResults.push({ type: 'property', key, value });
    };
    set('org.gradle.jvmargs', '-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:+HeapDumpOnOutOfMemoryError');
    set('org.gradle.daemon', 'false');
    if (process.env.APP_VARIANT === 'development') set('reactNativeArchitectures', 'arm64-v8a');
    return cfg;
  });
};
