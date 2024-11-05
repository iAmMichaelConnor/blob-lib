import cKzg from "c-kzg";
// import { resolve } from "path";
import { setupKzg, Kzg } from "viem";
// import { mainnetTrustedSetupPath } from "viem/node";

const { loadTrustedSetup } = cKzg;

// Leaving this here, commented-out, for posterity:
// const mainnetTrustedSetupPath = resolve(
//   "./node_modules/viem/trusted-setups/mainnet.json"
// );

// export const viemKzg = setupKzg(cKzg, mainnetTrustedSetupPath);

// The error type returned from the c++ binding is not quite a TS `Error` type, although it does seem to have the hallmark properties of an error: a `message` and a `stack`.
function isErrorLike(err: unknown): err is { message: string; stack?: string } {
  return (
    typeof err === "object" &&
    err !== null &&
    "message" in err &&
    typeof (err as any).message === "string" &&
    "stack" in err &&
    (typeof (err as any).stack === "string" ||
      typeof (err as any).stack === "undefined")
  );
}

export function wrappedLoadTrustedSetup() {
  console.log("\n\n\n\n\n\n\nHELLO");
  try {
    loadTrustedSetup();
  } catch (err) {
    if (isErrorLike(err)) {
      if (err.message === "Error trusted setup is already loaded") {
        // Do nothing. It's already loaded.
        console.log("Setup already loaded. Nothing to do.");
        return;
      }
    }
    // Otherwise:
    throw err;
  }
}

// Calling this globally is probably not the most sensible thing to do, as it's probably then re-called by every file that imports this file. If you use this, call it more carefully from within a function.
wrappedLoadTrustedSetup();

export { cKzg };

// Create an alternative version of viem's `Kzg` type, using methods from cKzg. We do this, because we were having trouble importing the common reference string to pass to viem's setupKzg function.
export const viemKzg: Kzg = {
  blobToKzgCommitment: cKzg.blobToKzgCommitment,
  computeBlobKzgProof: cKzg.computeBlobKzgProof,
};
