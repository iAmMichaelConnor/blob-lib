# blob-lib

What is this?

Mike getting some aztec-agnostic blob-submission stuff working, to demonstrate how it works, and to identify potential problems. It's in a separate repo because I didn't want to clutter-up aztec-packages until the design for blob submission is agreed.

There's a Noir circuit that validates that a collection of input fields corresponds to a blob of data that was submitted to L1.
There's a corresponding Solidity contract that accepts blob submissions and validates the correctness of the blob, by evaluating the blob commitment at a challenge and checking the result matches the circuit's own result.
There's some javascript tests that submit blobs to the smart contract and verify those blobs. 

TODO:
- Wait for Anvil blob submission bug fix (because currently this only works with a Hardhat node): https://github.com/foundry-rs/foundry/issues/8447
- Pray for brillig speedup, otherwise write custom oracles to compute bignum operations in typsecript, then feed-in the witnesses, because 30 min runtimes aren't practical for the Noir circuit.
- JS code to call the noir circuit, with tightly-packed example blob data.
- Understand the types and layouts of the data we will want to send to blobs.

NOT DOING, to save effort:
- Not going to verify the snark on L1. It does need to happen, but we can do that in aztec-packages.
- Not even going to submit the snark data to L1. It needs to happen, but this repo is just a rough demonstration of the stuff we _don't_ know how to do yet.

## More detail on the eventual intended flow:

1. Collect some data that you want to submit to L1 via blobs.
2. TODO: understand the types of the data we want to send to L1. Hopefully it's all AltBN254 Fr fields, so that they're neatly compatible with poseidon hashing.
    - In fact, we should just state this as a requirement: the data needs to be encoded as AltBN254 Fr fields. There. :)
3. We'll end up with a list of 4096 + 16 = 4112 field elements, per blob, each field being 254 bits.
4. Re-encode those 4112 field elements as 4096 BLS12-381 Fr elements, which are each of 255 bits.
    - I have an encoding in mind that I'll explain eventually. It involves splitting the final 16 fields into 4096 bits, and distributing a bit into the top-255th bit of each of the other 4096 bls-fields. Messy, but we don't want to waste 512 bytes per blob!
5. We now have a `blob`, comprising 4096 bls-fr fields.
5. Submit the blob to L1 (along with some other data that viem takes care of. Note: we'll need to think about how to choose a valid blob gas price and other gas parameters). The L1 contract calls the `blobhash(i)` opcode for the i-th blob of the tx, and stores the `versionedHash` that represents that blob. We store this hash, and defer calling the 'point evaluation precompile' until a later tx when we're ready to submit the final rollup proof - after all, calling this precompile only makes sense when done so in tandem with a circuit that validates the correctness of the choice of `y`. I haven't mentioned `y` yet, so I'm getting ahead of myself.
6. In typescript-land, compute the `commitment` to the blob, and the `versioned_hash` of the blob.
7. In noir-land, poseidon-hash the blob data in an arrangement that makes sense to the rest of our rollup circuits. I'm being vague with my wording, because I'm not sure of the best arrangement yet. Call this `blob_hash`. Also compute a poseidon-hash of the `commitment`; call this `commitment_hash`. Then `challenge = poseidon2(blob_hash, commitment_hash)`.
8. In noir-land, use the `challenge` as an input `z` to the barycentric formula for evaluating a polynomial outside of its domain, to yield a value `y = p(z)` (where `p(X)` is the polynomial that interpolates the `blob`).
9. The noir circuit outputs: `y`, `z = challenge`, `commitment`. We can also generate a zk-snark of this circuit - although in practice, the zk-snark that we submit to L1 will be a snark of the whole rollup; not just of this one circuit.
10. In typescript-land, compute a `kzg_proof`, which is essentially the commitment to the quotient polynomial `q(X) = (p(X) - y) / (X - z)`.
11. Send: `versioned_hash, z, y, commitment, kzg_proof`, and the zk-snark proof to the `verifyKzgProof` function of Blob.sol.
12. Call the point evaluation precompile contract with `versioned_hash, z, y, commitment, kzg_proof`, and it should return `success = true`.
13. Wooh! We've successfully proven that *"the underlying blob data that the circuit was fed, matches the blob data that was submitted to L1"*.

## Typescript & Solidity stuff:

Ignore, if thinking about circuits.

> [!IMPORTANT]  
> To reproduce the issue relating to not being able to submit blobs to an Anvil node:
> Happy path:
>
> Clone the repo.
>
> `cd blob-lib`
>
> `./bootstrap.sh`
>
> `yarn test:anvil`
>
> If that doesn't work, please interrogate the commands below and the bootstrap.sh script.

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
