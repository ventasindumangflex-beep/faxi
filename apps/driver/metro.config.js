// Expo SDK 52+ detecta el monorepo (npm workspaces) automáticamente.
const { getDefaultConfig } = require('expo/metro-config');
module.exports = getDefaultConfig(__dirname);
