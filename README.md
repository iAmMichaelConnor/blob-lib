# blob-lib

## Typescript & Solidity stuff:

Ignore, if thinking about circuits:

### Build

Clone this repo.

`cd blob-lib`

Either run bootstrap.sh or execute the individual commands yourself.

To run bootstrap:

`./bootstrap.sh`

Or alternatively:

`nvm use 18`

`yarn install`

`yarn build`

To install foundry (which is really a bit of overkill in this situation, because we really just need solc to compile the contract):

`cd contracts`

`forge install --no-commit`

`git submodule update --init --recursive ./lib`

To compile `contracts/src/Blob.sol`:

From `./contracts`:

`forge build --evm-version cancun`

This creates `./contracts/out/Blob.sol/Blob.json`, which the ts tests then read.

### Run Tests:

The tests spin up a local ethereum node and run a couple of jest tests which submit blob transactions:

To run the tests against an Anvil node (which fail):

`yarn test:anvil`

To run the tests against a Hardhat network node (which succeed):

`yarn test:hardhat`

## Noir stuff:

### Build

Clone the repo.

`cd blob-lib`

You have two choices:

- `git checkout main` will run for domain size of 8. (Recommended to make the tests actually work).
- `git checkout domain-size-4096` for the domain size of 16 (which takes ~10 minutes to run on a beefy machine, because Brillig isn't optimised yet).

`cd noir-circuits/blob`

`nargo compile` or jump straight to the test:

### Noir Tests

`nargo test --show-output test_barycentric`

Currently, it takes ~7 seconds to run a single test for domain size 8.

#### To run with domain size 4096

`git checkout domain-size-4096`

Or, you can swap the `mod` and `use` statements here in main.nr:

```rust
// ONLY IMPORT ONE OF THESE CONFIGS! The big `config` is too big to compile yet (I waited an hour and gave up).
// mod config;
mod smaller_config;

// ONLY CHOOSE ONE OF THESE IMPORTS:
// use crate::config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};
use crate::smaller_config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};
```

The following takes > 10 minutes on a beefy machine:

`nargo test --show-output test_barycentric`
