
// ONLY IMPORT ONE OF THESE CONFIGS! The big `config` is too big to compile yet (I waited an hour and gave up).
// mod config;
mod smaller_config;

// use crate::config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};
use crate::smaller_config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};


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

    // This doesn't throw an error - hooray!
    BigNum::evaluate_quadratic_expression([[z]], [[false]], [[z]], [[false]], [t1], [true]);

    let mut t2: F = BigNum::new();
    for _i in 0..LOG_FIELDS_PER_BLOB - 1 {
        t2 = t1.__mulmod(t1);

        // GRATUITOUS USAGE OF as_witness, LIKE THROWING DARTS AT A DARTBOARD AND HOPING THIS HELPS
        std::as_witness(t2.limbs[0]);
        std::as_witness(t2.limbs[1]);
        std::as_witness(t2.limbs[2]);

        // This doesn't throw an error - hooray!
        BigNum::evaluate_quadratic_expression([[t1]], [[false]], [[t1]], [[false]], [t2], [true]);

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

    // This errors:
    // BigNum::evaluate_quadratic_expression(
    //     [[t1]],
    //     [[false]],
    //     [[D_INV]],
    //     [[false]],
    //     [factor],
    //     [true]
    // );

    // I actually don't know how to use this function to evaluate a simple non-quadratic constraint. Maybe I shouldn't be, and I shoult be calling the sub / add functions?
    // This errors:
    // BigNum::evaluate_quadratic_expression(
    //     [[]],
    //     [[]],
    //     [[]],
    //     [[]],
    //     [z_pow_d, one, t1],
    //     [false, true, true]
    // );


    // sum:

    let mut sum: F = BigNum::new();
    let mut fracs: [F; FIELDS_PER_BLOB] = [BigNum::new(); FIELDS_PER_BLOB];
    for i in 0..FIELDS_PER_BLOB {
        let root_i = ROOTS[i];
        let num = root_i;
        let denom = z.__submod(root_i);
        std::as_witness(denom.limbs[0]);
        std::as_witness(denom.limbs[1]);
        std::as_witness(denom.limbs[2]);

        let frac = num.__divmod(denom);
        std::as_witness(frac.limbs[0]);
        std::as_witness(frac.limbs[1]);
        std::as_witness(frac.limbs[2]);

        // I was trying to combine the above div and sub into one call to `evaluate_quadratic_constraint`, but I'm not sure that's sound... and it breaks anyway.
        // This errors:
        // BigNum::evaluate_quadratic_expression(
        //     [[denom]],
        //     [[false]],
        //     [[frac]],
        //     [[false]],
        //     [num, z, root_i, denom],
        //     [true, false, true, true]
        // );

        fracs[i] = frac;
        std::as_witness(fracs[i].limbs[0]);
        std::as_witness(fracs[i].limbs[1]);
        std::as_witness(fracs[i].limbs[2]);

        let summand = ys[i].__mulmod(frac);
        std::as_witness(summand.limbs[0]);
        std::as_witness(summand.limbs[1]);
        std::as_witness(summand.limbs[2]);

        sum = sum.__addmod(summand);
        std::as_witness(sum.limbs[0]);
        std::as_witness(sum.limbs[1]);
        std::as_witness(sum.limbs[2]);
    }

    // I was hoping I could do this, which would be nice and efficient.
    // This errors:
    // BigNum::evaluate_quadratic_expression(
    //     [ys],
    //     [[false; FIELDS_PER_BLOB]],
    //     [fracs],
    //     [[false; FIELDS_PER_BLOB]],
    //     [sum],
    //     [true]
    // );


    // y:

    let y = factor.__mulmod(sum);

    // This errors:
    // BigNum::evaluate_quadratic_expression([[factor]], [[false]], [[sum]], [[false]], [y], [true]);

    println(y);

    y
}


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

    // Computed with the eth consensus specs py lib (after hacking it to cope with blobs of size 8 instead of 4096):
    // THIS CHECK IS ONLY VALID USING THE simple_config.nr:
    assert(y.limbs[0] == 0xb04cdea4304000053abffffffb203a);
    assert(y.limbs[1] == 0x0000000002e30785c8afa4496f8e38);
    assert(y.limbs[2] == 0x000000);
}
