# blob-lib

# Noir stuff:

Before compiling, you need to add this Field definition to Zac's bigint library, locally, and then add corresponding new `mod` and `use` statements in fields.nr and lib.nr.

The Nargo.toml points to a version of Zac's bigint library on Mike's machine; you'll need to update that path.

```rust
use crate::BigNum;
use crate::BigNumParamsTrait;

struct Bls12_381_Fr_Params {}

impl BigNumParamsTrait<3> for Bls12_381_Fr_Params {
    fn redc_param() -> [Field; 3] {
        [ 0x410fad2f92eb5c509cde80830358e4, 0x253b7fb78ddf0e2d772dc1f823b4d9, 0x008d54 ]
    }
    fn modulus() -> [Field; 3] {
        [ 0xbda402fffe5bfeffffffff00000001, 0xa753299d7d483339d80809a1d80553, 0x0073ed ]
    }
    fn double_modulus() -> [Field; 3] {
        [ 0x7b4805fffcb7fdfffffffe00000002, 0x4ea6533afa906673b0101343b00aa7, 0x00e7db ]
    }
    fn k() -> u64 {
        255
    }
    fn modulus_bits() -> u64 {
        255
    }
}
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
