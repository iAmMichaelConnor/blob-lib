## Constraint counts

Current count: 428,240.

113,776 is poseidon2-hashing the blob's fields. This _could_ be replaced by a databus commitment, if Noir could be given access to such a commitment. Although, that idea might not work, as it would require non-native EC Pairings on commitments to hone-in on only the part of the databus commitment which represents the blob.

## Compile:

`time nargo compile `

## Get gate count:

Install bbup: `curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash`
The version of bb compatible with nargo 0.33.0 is `bbup --version 0.48.0`

`time bb gates_mega_honk -b ./target/blob.json`

## Generate, then serve a new flamegraph, after compiling:

<!-- `~/packages/noir/noir-repo/target/release/noir-profiler gates-flamegraph --artifact-path ./target/blob.json --backend-path ~/.bb/bb --output ./flamegraph -- -h && python3 -m http.server --directory "./flamegraph" 3000` -->

`~/packages/noir/noir-repo/target/release/noir-profiler gates-flamegraph --artifact-path ./target/blob.json --backend-path ~/.bb/bb --output ./flamegraph --backend-gates-command "gates_mega_honk" -- -h && python3 -m http.server --directory "./flamegraph" 3000`

## To serve an existing flamegraph:

`python3 -m http.server --directory "./flamegraph" 3000`
