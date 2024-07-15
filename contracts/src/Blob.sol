// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.26;

contract Blob {
    uint256 internal constant BLS_MODULUS =
        52435875175126190479447740508185965837690552500527637822603658699938581184513;
    uint256 internal constant FIELD_ELEMENTS_PER_BLOB = 4096;

    uint256 txId;
    mapping(uint256 txId => mapping(uint256 blobIndex => bytes32 blobHash)) blobHashes;

    event BlobHash(uint256 _txId, bytes32 _blobhash);
    event PointEvaluationSuccess(bool _success);

    /**
     * You don't actually need to call a function to submit a blob; the tx payload
     * can be empty. I'm calling this function so that the blob's versioned_hash
     * (aka blobhash) can be accessed and stored for later. You can only
     * access the blobhash in the tx in which the blob was submitted.
     */
    function submitBlobs() external {
        /**
         * blobhash(i) returns the versioned_hash of the i-th blob associated with _this_ transaction.
         * bytes[0:1]: 0x01
         * bytes[1:32]: the last 31 bytes of the sha256 hash of the kzg commitment C.
         */
        bytes32 blobHash;
        assembly {
            blobHash := blobhash(0)
        }
        blobHashes[txId][0] = blobHash;
        emit BlobHash(txId, blobHash);

        ++txId;
    }

    // /**
    //  * Input bytes:
    //  * input[:32]     - versioned_hash
    //  * input[32:64]   - z
    //  * input[64:96]   - y
    //  * input[96:144]  - commitment C
    //  * input[144:192] - proof (a commitment to the quotient polynomial q(X))
    //  *
    //  * where:
    //  *     p(X) interpolates the values in the blob, at roots of unity [^1]
    //  *     p(z) = y
    //  *     Commitment C is the kzg commitment of p(X)
    //  *     Proof is the kzg commitment of q(X) = (p(X) - p(z))/(X - z)
    //  *
    //  * Note: the roots of unity are arranged in bit-reversal permutation, so you'll need a library to play with this stuff. You won't be able to mentally play with the polynomials.
    //  */
    function verifyKzgProof(bytes calldata input, uint256 _txId) public {
        // Check that the input blobhash matches the one submitted earlier:
        require(blobHashes[_txId][0] == bytes32(input[0:32]));

        // Staticcall the point eval precompile https://eips.ethereum.org/EIPS/eip-4844#point-evaluation-precompile :
        (bool success, bytes memory data) = address(0x0a).staticcall(input);
        require(success, "Point evaluation precompile failed");

        // Validate that it actually actually succeeded, by checking that the
        // precompile returned the hard-coded values that it always should.
        // TODO: we probably don't need to check both values - I'm just doing this
        // to have a record of how to extract both values, and what they are.
        {
            (uint256 fieldElementsPerBlob, uint256 blsModulus) = abi.decode(
                data,
                (uint256, uint256)
            );
            require(
                fieldElementsPerBlob == FIELD_ELEMENTS_PER_BLOB,
                "Point eval precompile failed"
            );
            require(blsModulus == BLS_MODULUS, "Point eval precompile failed");
        }

        emit PointEvaluationSuccess(success);
    }
}
