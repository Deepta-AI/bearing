// NativeWind needs jsxImportSource so className compiles to StyleSheet; the
// reanimated plugin is loaded by babel-preset-expo (worklets) automatically.
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [['babel-preset-expo', { jsxImportSource: 'nativewind' }], 'nativewind/babel'],
  };
};
