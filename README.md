# blob-lib

# Noir stuff:

Uses this fork of Zac's bignum lib. (The fork is only needed because the BLS12-381 params haven't been merged into Zac's main branch yet :) )

https://github.com/iAmMichaelConnor/noir-bignum

https://github.com/zac-williamson/noir-bignum/pull/2

## Build

Clone the repo.

`cd blob-lib`

You have two choices:

- `git checkout main` will run for domain size of 8. (Recommended to make the tests actually work).
- `git checkout domain-size-4096` for if you want to help debug why the test takes >1 hour to run.

`cd noir-circuits/blob`
`nargo compile` or jump straight to the test:

## Test

`nargo test --show-output`

Currently, it takes ~1 min to run a single test for domain size 8.

NOTE: this lib doesn't use a domain size of 4096 yet - it only uses 8. The test took so long I didn't wait for it to finish for a domain of size 4096.

NOTE: this circuit is mostly unconstrained still, because the `evaluate_quadratic_constraint()` calls throw errors. It could be me misunderstanding how to use this function.

## To run with domain size 4096

`git checkout domain-size-4096`

> I don't know how long this would take to run `nargo test --show-output`, but it's longer than an hour.

> Note: **the test will fail** because I haven't hard-coded the correct y value in the test's assertion; the currently-hard-coded value is intentionally for domain size 8.

Or, you can swap the `mod` and `use` statements here in main.nr:

```rust
// ONLY IMPORT ONE OF THESE CONFIGS! The big `config` is too big to compile yet (I waited an hour and gave up).
// mod config;
mod smaller_config;

// ONLY CHOOSE ONE OF THESE IMPORTS:
// use crate::config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};
use crate::smaller_config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};
```

# Typescript & Solidity stuff:

Ignore, if thinking about circuits:

## Build

Clone this repo.

`cd blob-lib`
`nvm use 18`
`yarn install`
`yarn build`

## Compiling Contract

To install foundry (which is really a bit of overkill in this situation, because we really just need solc):

`cd contracts`
`forge install --no-commit`
`git submodule update --init --recursive ./lib`

To compile `contracts/src/Blob.sol`:
From `./contracts`:

`forge build --evm-version cancun`

This creates `./contracts/out/Blob.sol/Blob.json`, which the ts tests then read.

## To run blob submission smart contract tests:

Start a hardhat network node in one window:

`npx hardhat node`

(Note: anvil doesn't seem to work with my blob txs)

Then in another window:

`export PRIV_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` - this is the default testing private key for anvil and hardhat.
`yarn test`

## Notes

It will first send an ordinary eth transfer tx, to demonstrate that this works.

Then it will try to send a blob tx, in keeping with https://viem.sh/docs/guides/blob-transactions. This blob tx will fail with:

```
InvalidParamsRpcError: Invalid parameters were provided to the RPC method.
Double check you have provided the correct parameters.
```

and later:

```
shortMessage: 'RPC Request failed.',
version: 'viem@2.17.2',
cause: { code: -32602, message: 'Failed to decode transaction' },
```

---

Ok, so I had a go at sending the same txs (using the same tests) to a "hardhat network node".
Interestingly (confusingly and frustratingly), if you `client.sendRawTransaction` to a hardhat node, the tx data is formatted _differently_ from when it's sent to a foundry node. That's with the same client configuration `chain: foundry`. Viem seemingly figures out that it's talking with a hardhat node and _reformats_ the `sendRawTransaction` request to be in a non-raw, jsonified format. But hardhat can't understand a jsonified blob tx\*; it only supports raw (rlp-encoded) blob tx requests formatted with sendRawTransaction - except viem's `sendRawTransaction` is reformatting the request into json form for a hardhat node (but not for an anvil node)!!! Setting `chain: hardhat` didn't help, so I kept it at `foundry`. This `foundry` setting didn't affect non-blob txs from being successfully processed by the hardhat node.

> \* Hardhat says this when you feed it a jsonified, non-raw tx:
> `An EIP-4844 (shard blob) call request was received, but Hardhat only supports them via 'eth_sendRawTransaction'. See https://github.com/NomicFoundation/hardhat/issues/5182` ([link](https://github.com/NomicFoundation/hardhat/issues/5182))

So how to send a raw tx to a hardhat node? Curl! But the size of the blob is way bigger than what curl allows. So I stored the command in a text file `raw-tx.json` and did:

`curl -X POST -H "Content-Type: application/json" --data @raw-tx.json 127.0.0.1:8545`

Hooray! The hardhat network node didn't complain - it gave me a tx receipt!

I tried the same with anvil and got: "Failed to decode transaction" - the same error as I've been getting all along from anvil, even if sending via viem.

> Note: the nonce for the `raw-tx.json` is nonce 0 (encoded as `0x80` "nothing here"), so if it fails, you'll need to restart anvil to run it again. Or you could manually modify the nonce:
> From the start of the raw params string, it's here:
>
> ```
> "0x03fa020102f894827a6980...
>                        ^^ these two bytes are the nonce
>                          `80` means nonce `0`, `01` is nonce `1`. `02` is nonce `2`, etc.
> ```

<!-- prettier-ignore -->
|   | Viem | Curl |
|---|---|---|
| anvil node  | ❌ `InvalidParamsRpcError: Invalid parameters were provided to the RPC method.`  | ❌ `InvalidParamsRpcError: Invalid parameters were provided to the RPC method.`  |
| hardhat network node | ❌ `An EIP-4844 (shard blob) call request was received, but Hardhat only supports them via 'eth_sendRawTransaction'. See https://github.com/NomicFoundation/hardhat/issues/5182` but viem isn't sending the tx as raw. | ✅ |

Oooh, it's calling estimate_gas that seems to be killing it. If you specify all gas values (gas limit, max fee per ...) then it seems to work - for hardhat at least!
