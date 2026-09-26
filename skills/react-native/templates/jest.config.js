// jest-expo runs React Native components on Node; nothing here needs a device.
module.exports = {
  preset: 'jest-expo',
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' },
  testPathIgnorePatterns: ['/node_modules/', '/dist/', '/ios/', '/android/', '/.expo/'],
  collectCoverageFrom: ['app/**/*.tsx', 'src/**/*.{ts,tsx}', '!**/*.test.{ts,tsx}', '!**/*.d.ts'],
  coverageReporters: ['text', 'cobertura'],
  coverageDirectory: 'coverage',
};
