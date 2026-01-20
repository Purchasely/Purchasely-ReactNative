module.exports = {
  plugins: ['@typescript-eslint'],
  extends: [
    '@react-native-community',
    'plugin:@typescript-eslint/recommended',
    'prettier',
  ],
  ignorePatterns: [
    '**/.next/**.**',
    '**/lib/**',
    '**/node_modules/**',
    '**/build/**',
    '**/__tests__/**',
    '**/__mocks__/**',
  ],
  rules: {
    '@typescript-eslint/no-unused-vars': 'off',
    '@typescript-eslint/no-explicit-any': 'off',
    'react-hooks/exhaustive-deps': 'off',
    'react/no-unescaped-entities': 'off',
    '@typescript-eslint/ban-ts-comment': 'off',
    'prettier/prettier': 'off',
    'no-shadow': 'off',
  },
}
