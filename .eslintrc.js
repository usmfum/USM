module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: ['prettier'],
  env: { node: true, mocha: true },
  globals: { contract: true, artifacts: true, web3: true },
  rules: {
    'prettier/prettier': 'error',
  },
  extends: ['eslint:recommended', 'plugin:prettier/recommended'],
}
