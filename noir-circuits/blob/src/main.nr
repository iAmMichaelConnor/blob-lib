// ONLY IMPORT ONE OF THESE CONFIGS! The big `config` is too big to compile yet (I waited an hour and gave up).
// mod config;
mod smaller_config;

// ONLY CHOOSE ONE OF THESE IMPORTS:
// use crate::config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};
use crate::smaller_config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};

unconstrained fn __batch_invert_impl<let N: u64>(mut x: [F; N]) -> [F; N] {
    let mut accumulator: F = BigNum::one();

    let mut temporaries: [F] = &[];
    for i in 0..x.len() {
        temporaries = temporaries.push_back(accumulator);
        if (x[i].__is_zero() == false) {
            accumulator = accumulator.__mulmod(x[i]);
        }
    }

    accumulator = accumulator.__invmod();
    let mut T0: F = BigNum::new();
    for i in 0..x.len() {
        let idx = x.len() - 1 - i;
        if (x[idx].__is_zero() == false) {
            T0 = accumulator.__mulmod(temporaries[idx]);
            accumulator = accumulator.__mulmod(x[idx]);
            x[idx] = T0;
        }
    }
    x
}

unconstrained fn __compute_inv_denoms(z: F) -> [F; FIELDS_PER_BLOB] {
    let mut denoms: [F; FIELDS_PER_BLOB] = [BigNum::new(); FIELDS_PER_BLOB];
    for i in 0..FIELDS_PER_BLOB {
        denoms[i] = z.__submod(ROOTS[i]);
    }
    __batch_invert_impl(denoms)
}

/**
 *                    ___d-1 
 *         z^d - 1    \            ω^i
 * p(z) = --------- . /   y_i . ---------
 *            d      /____       z - ω^i
 *                    i=0
 *
 * p(z) = factor . sum( y_i . num / denom )
 *
 *
 * where d = 4096
 *
 * Precompute:
 * - The d roots of unity ω^i (plus maybe their negatives for z - ω^i computations).
 * - (1 / d)
 *                   
 */
fn main(z: F, ys: [F; FIELDS_PER_BLOB]) -> pub F {
    // z ^ D:

    let mut t1 = z.__mulmod(z);

    // BigNum::evaluate_quadratic_expression([[z]], [[false]], [[z]], [[false]], [t1], [true]);

    let mut t2: F = BigNum::new();
    for _i in 0..LOG_FIELDS_PER_BLOB - 1 {
        t2 = t1.__mulmod(t1);

        // GRATUITOUS USAGE OF as_witness, LIKE THROWING DARTS AT A DARTBOARD AND HOPING THIS HELPS
        std::as_witness(t2.limbs[0]);
        std::as_witness(t2.limbs[1]);
        std::as_witness(t2.limbs[2]);

        // BigNum::evaluate_quadratic_expression([[t1]], [[false]], [[t1]], [[false]], [t2], [true]);

        t1 = t2;
        std::as_witness(t1.limbs[0]);
        std::as_witness(t1.limbs[1]);
        std::as_witness(t1.limbs[2]);
    }

    let z_pow_d = t1;

    // factor:

    let one: F = BigNum::one();

    t1 = z_pow_d.__submod(one);
    std::as_witness(t1.limbs[0]);
    std::as_witness(t1.limbs[1]);
    std::as_witness(t1.limbs[2]);

    let factor = t1.__mulmod(D_INV);

    // (z_pow_d - one) * (D_INV) - factor = 0
    // z_pow_d * D_INV - D_INV - factor = 0
    // BigNum::evaluate_quadratic_expression(
    //     [[z_pow_d]],
    //     [[false]],
    //     [[D_INV]],
    //     [[false]],
    //     [factor, D_INV],
    //     [true, true]
    // );

    //  // This version doesn't work:
    //  // BigNum::evaluate_quadratic_expression(
    //  //     [[z_pow_d, one]],
    //  //     [[false, true]],
    //  //     [[D_INV]],
    //  //     [[false]],
    //  //     [factor],
    //  //     [true]
    //  // );

    // sum:

    let mut sum: F = BigNum::new();
    let mut fracs: [F; FIELDS_PER_BLOB] = [BigNum::new(); FIELDS_PER_BLOB];

    // Making a call to this function causes a "stack too deep" error, so I've put the body of that function here, instead:
    // let inv_denoms = __compute_inv_denoms(z);

    let mut denoms = [BigNum::new(); FIELDS_PER_BLOB];
    for i in 0..FIELDS_PER_BLOB {
        denoms[i] = z.__submod(ROOTS[i]);
    }
    let inv_denoms = __batch_invert_impl(denoms);

    for i in 0..FIELDS_PER_BLOB {
        let root_i = ROOTS[i];
        let num = root_i;
        let inv_denom = inv_denoms[i];

        let frac = num.__mulmod(inv_denom);

        // roots[i] / (z - roots[i]) = frac 
        // && (z - roots[i]) * inv_denom = 1.
        //
        // frac * (z - roots[i]) - roots[i] = 0
        // inv_denom * (z - roots[i]) - 1 = 0
        //
        // (frac + inv_denom) * (z - roots[i]) - roots[i] - 1 = 0
        //
        // // BigNum::evaluate_quadratic_expression(
        // //     [[frac, inv_denom]],
        // //     [[false, false]],
        // //     [[z, ROOTS[i]]],
        // //     [[false, true]],
        // //     [ROOTS[i], one],
        // //     [true, true]
        // // );

        // Alternative:
        // BigNum::evaluate_quadratic_expression(
        //     [[frac]],
        //     [[false]],
        //     [[z, ROOTS[i]]],
        //     [[false, true]],
        //     [ROOTS[i]],
        //     [true]
        // );
        // BigNum::evaluate_quadratic_expression(
        //     [[inv_denom]],
        //     [[false]],
        //     [[z, ROOTS[i]]],
        //     [[false, true]],
        //     [one],
        //     [true]
        // );

        fracs[i] = frac;
        std::as_witness(fracs[i].limbs[0]);
        std::as_witness(fracs[i].limbs[1]);
        std::as_witness(fracs[i].limbs[2]);
    }

    let SUM_SLICES = FIELDS_PER_BLOB / 8 + ((FIELDS_PER_BLOB % 8 != 0) as u64);
    // let SUM_SLICES = FIELDS_PER_BLOB / 8;

    // OK so...we can add multiple product terms into a sum...but I am not sure how many!
    // we are computing 254 * 254 bit products and we need to ensure each product limb doesn't overflow
    // each limb is 120 bits => 120 * 120 = 240 bits.
    // however when computing a mul we add up to 5 product terms into a single field element => 243 bits (ish)
    // when we do a modular reduction we validate that a field element >> 120 bits is less than 2^{126} which implies we have 246 bits to play with
    // which implies...we can accomodate up to EIGHT additions of product terms before we risk overflowing
    // (this is really messy! I never considered the case of giant linear sequences of products)
    let mut sum: F = BigNum::new();
    for i in 0..SUM_SLICES - 1 {
        // for i in 0..SUM_SLICES {
        let mut partial_sum: F = BigNum::new();
        let mut lhs: [F; 8] = [BigNum::new(); 8];
        let mut rhs = lhs;

        for j in 0..8 {
            lhs[j] = ys[i * 8 + j];
            rhs[j] = fracs[i * 8 + j];

            std::as_witness(lhs[j].limbs[0]);
            std::as_witness(lhs[j].limbs[1]);
            std::as_witness(lhs[j].limbs[2]);
            std::as_witness(rhs[j].limbs[0]);
            std::as_witness(rhs[j].limbs[1]);
            std::as_witness(rhs[j].limbs[2]);

            let summand = ys[i].__mulmod(fracs[i]);
            partial_sum = partial_sum.__addmod(summand);

            std::as_witness(partial_sum.limbs[0]);
            std::as_witness(partial_sum.limbs[1]);
            std::as_witness(partial_sum.limbs[2]);
        }
        let mut sum_out = sum.__addmod(partial_sum);
        // BigNum::evaluate_quadratic_expression(
        //     [lhs],
        //     [[false; 8]],
        //     [rhs],
        //     [[false; 8]],
        //     [sum, sum_out],
        //     [false, true]
        // );
        sum = sum_out;
        std::as_witness(sum.limbs[0]);
        std::as_witness(sum.limbs[1]);
        std::as_witness(sum.limbs[2]);
    }

    // ok so if FIELDS_PER_BLOB does not divide by 8 we have a problem. Thankfully it always does, so I've commented-out this :)
    // evaluate_quadratic_expression needs constant-sized arrays,
    // and we can't currently derive array size params from variables (e.g. FIELDS_PER_BLOB / 8)
    // sooooo we just do the final 8 terms individually. yes this is really messy
    let overhang_start = (SUM_SLICES - 1) * 8;
    let overhang_end = FIELDS_PER_BLOB;
    for i in overhang_start..overhang_end {
        let sum_out = sum.__addmod(ys[i].__mulmod(fracs[i]));
        // BigNum::evaluate_quadratic_expression(
        //     [[ys[i]]],
        //     [[false]],
        //     [[fracs[i]]],
        //     [[false]],
        //     [sum, sum_out],
        //     [false, true]
        // );
        sum = sum_out;
        std::as_witness(sum.limbs[0]);
        std::as_witness(sum.limbs[1]);
        std::as_witness(sum.limbs[2]);
    }

    // I was hoping I could do this, which would be nice and efficient.
    // This errors:
    // // BigNum::evaluate_quadratic_expression(
    // //     [ys],
    // //     [[false; FIELDS_PER_BLOB]],
    // //     [fracs],
    // //     [[false; FIELDS_PER_BLOB]],
    // //     [sum],
    // //     [true]
    // // );

    // y:

    let y = factor.__mulmod(sum);

    // BigNum::evaluate_quadratic_expression([[factor]], [[false]], [[sum]], [[false]], [y], [true]);

    println(y);

    y
}

// nargo test --show-output test_main
#[test]
fn test_main() {
    let z: F = BigNum { limbs: [2, 0, 0] };

    // many y's form a blob:
    let mut ys: [F; FIELDS_PER_BLOB] = [BigNum::new(); FIELDS_PER_BLOB];

    ys[0] = BigNum { limbs: [0x1234, 0, 0] };
    ys[1] = BigNum { limbs: [0xabcd, 0, 0] };
    ys[2] = BigNum { limbs: [0x69, 0, 0] };

    // evaluate the blob at z = 2 to yield y:
    let y = main(z, ys);

    let mut expected_y: [Field; 3] = [0; 3];
    if (FIELDS_PER_BLOB == 4096) {
        // Computed with the eth consensus specs py lib
        expected_y = [
            0x0c62e352a428e8e9842eadc1c106bd, 
            0x902c5b4968d755b6f49c0231e15af8,
            0x00049a
        ];
        // Also computed with cKzg, in the typescript tests:
        // 0x049a902c5b4968d755b6f49c0231e15af80c62e352a428e8e9842eadc1c106bd
    }
    if (FIELDS_PER_BLOB == 8) {
        // Computed with the eth consensus specs py lib (after hacking it to cope with blobs of size 8 instead of 4096):
        expected_y = [
            0xb04cdea4304000053abffffffb203a, 
            0x0000000002e30785c8afa4496f8e38,
            0x000000
        ];
    }
    assert(y.limbs == expected_y);
}

unconstrained fn compute_double_modulus() -> [Field; 3] {
    let two_p = [0x7b4805fffcb7fdfffffffe00000002, 0x4ea6533afa906673b0101343b00aa7, 0x00e7db];
    let NUM_LIMBS = 3; // must be >= 3
    let two_pow_120 = 2.pow_32(120); // 120 or 128?
    let mut double_modulus: [Field; 3] = [0; 3];

    double_modulus[0] = two_p[0] + two_pow_120;
    for i in 1..NUM_LIMBS - 1 {
        double_modulus[i] = two_p[i] + two_pow_120 - 1;
    }
    double_modulus[NUM_LIMBS - 1] = two_p[NUM_LIMBS - 1] - 1;
    double_modulus
}

// nargo test --show-output test_compute_double_modulus
#[test]
fn test_compute_double_modulus() {
    println(compute_double_modulus());
}

// nargo test --show-output test_compute_d_inv
#[test]
fn test_compute_d_inv() {
    let D_INV = D.__invmod();
    println(D_INV);
}

