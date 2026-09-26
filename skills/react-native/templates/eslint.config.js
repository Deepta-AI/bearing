// Flat config: Expo's rules (react, react-hooks, import, typescript), the
// TanStack Query rules, then Prettier last to switch off style rules.
const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');
const pluginQuery = require('@tanstack/eslint-plugin-query');
const prettier = require('eslint-config-prettier');

module.exports = defineConfig([
  expoConfig,
  ...pluginQuery.configs['flat/recommended'],
  prettier,
  {
    ignores: ['dist/**', 'ios/**', 'android/**', 'coverage/**', '.expo/**', 'node_modules/**'],
  },
  {
    files: ['app/**/*.tsx', 'src/**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-non-null-assertion': 'error',
      'no-restricted-imports': [
        'error',
        {
          paths: [
            {
              name: 'react-native',
              importNames: ['SafeAreaView'],
              message: 'Use SafeAreaView from react-native-safe-area-context.',
            },
          ],
        },
      ],
    },
  },
]);
