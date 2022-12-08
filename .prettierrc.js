const ts = require('eslint-config-mimic/prettier')
const solidity = require('solhint-config-mimic/prettier')

module.exports = {
  printWidth: 100,
  overrides: [
    ts,
    solidity
  ]
}
