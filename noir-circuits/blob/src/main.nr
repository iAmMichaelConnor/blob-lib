mod config;

// use dep::bigint::{BigNum, fields::{bn254Fq::BNParams}};
use crate::config::{BigNum, Bls12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, D, D_INV, ROOTS};

// The BN Fr Field size: don't change this.
global FIELD_MODULUS: [Field; 3] = [
    0x000000000000000000000000000000000033E84879B9709143E1F593F0000001, 0x00000000000000000000000000000000004E72E131A029B85045B68181585D28, 0x0000000000000000000000000000000000000000000000000000000000003064
];

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
fn main(z: F, ys: [F; FIELDS_PER_BLOB]) -> pub Field {
    // let y: F = field_to_bignum(x);

    // z ^ 4096
    let mut count = 0;
    let mut t1 = z.__mulmod(z);
    // BigNum::evaluate_quadratic_expression([[z]], [[false]], [[z]], [[false]], [t1], [true]);
    println(t1);
    count += 1;

    let mut t2: F = BigNum::new();
    for _i in 0..LOG_FIELDS_PER_BLOB - 1 {
        t2 = t1.__mulmod(t1);
        std::as_witness(t2.limbs[0]);
        std::as_witness(t2.limbs[1]);
        std::as_witness(t2.limbs[2]);

        // BigNum::evaluate_quadratic_expression([[t1]], [[false]], [[t1]], [[false]], [t2], [true]);
        count += 1;
        t1 = t2;
        std::as_witness(t1.limbs[0]);
        std::as_witness(t1.limbs[1]);
        std::as_witness(t1.limbs[2]);

        println(t1);
    }

    let z_pow_d = t1;
    println(z_pow_d);

    assert(count == LOG_FIELDS_PER_BLOB);

    // factor

    let one: F = BigNum::one();

    t1 = z_pow_d.__submod(one);
    std::as_witness(t1.limbs[0]);
    std::as_witness(t1.limbs[1]);
    std::as_witness(t1.limbs[2]);

    let factor = t1.__mulmod(D_INV);
    // BigNum::evaluate_quadratic_expression(
    //     [[t1]],
    //     [[false]],
    //     [[D_INV]],
    //     [[false]],
    //     [factor, z_pow_d, one, t1],
    //     [true, false, true, true]
    // );

    // sum
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

    // BigNum::evaluate_quadratic_expression(
    //     [ys],
    //     [[false; FIELDS_PER_BLOB]],
    //     [fracs],
    //     [[false; FIELDS_PER_BLOB]],
    //     [sum],
    //     [true]
    // );

    let y = factor.__mulmod(sum);

    // BigNum::evaluate_quadratic_expression([[factor]], [[false]], [[sum]], [[false]], [y], [true]);

    println(y);

    y.limbs[0]
}

// Limbs are little-endian. The content of each limb is big-endian.
// It would be more efficient to implement a `sub` method and check the carry
unconstrained fn __limbs_gt<let N: u64>(x: [Field; N], y: [Field; N]) -> bool {
    let mut result: Field = 0;

    // Working backwards through the limbs, find the first nonzero comparison point.
    let mut biggest_nonzero_limb_index = N - 1;
    for i in 0..N {
        let j = N - i - 1;
        if (x[j] != 0) | (y[j] != 0) {
            biggest_nonzero_limb_index = j;
            break;
        }
    }

    // Working from the first comparable limbs, decompose each limb into bytes, and compare the bytes from their big end to their little end until you find which is greater.
    for i in 0..biggest_nonzero_limb_index + 1 {
        let j = biggest_nonzero_limb_index - i;

        let x_bytes = x[j].to_be_bytes(15);
        let y_bytes = y[j].to_be_bytes(15);

        for k in 0..15 {
            if x_bytes[k] == y_bytes[k] {
                continue;
            }
            if x_bytes[k] > y_bytes[k] {
                result = 1;
                break;
            }
            result = 2;
            break;
        }
        if result != 0 {
            break;
        }
    }

    result == 1
}

unconstrained fn __field_to_bytes(x: Field) -> [u8; 32] {
    let x_bytes_slice = x.to_be_bytes(32);
    let mut x_bytes = [0; 32];
    for i in 0..32 {
        x_bytes[i] = x_bytes_slice[i];
    }
    x_bytes
}

unconstrained fn __field_to_bignum(x: Field) -> F {
    let x_bytes = __field_to_bytes(x);
    BigNum::from_byte_be(x_bytes)
}

unconstrained fn __field_to_bignum_limbs(x: Field) -> [Field; 3] {
    __field_to_bignum(x).limbs
}

// Only works for bignums with modulus larger than the BN Fr size.
fn field_to_bignum(x: Field) -> F {
    assert(__limbs_gt(Bls12_381_Fr_Params::modulus(), FIELD_MODULUS));
    let __x_limbs = __field_to_bignum_limbs(x);

    let mut check = __x_limbs[3 - 1];
    let limb_max = 2.pow_32(120);
    for i in 1..3 {
        check *= limb_max;
        check += __x_limbs[3 - i - 1];
    }
    assert(check == x);

    BigNum { limbs: __x_limbs }
}

fn bignum_to_field(x: F) -> Field {
    let mut result: Field = 0;
    let limb_max = 2.pow_32(120);
    result += x.limbs[3 - 1];
    for i in 1..3 {
        result *= limb_max;
        result += x.limbs[3 - i - 1];
    }
    result
}

#[test]
fn test_main() {
    let z: F = BigNum { limbs: [2, 0, 0] };

    let mut y: [F; FIELDS_PER_BLOB] = [BigNum::new(); 4096];

    y[0] = BigNum { limbs: [0x0000000000000000000000000000000000000000000000000000000000001234, 0, 0] };
    y[1] = BigNum { limbs: [0x000000000000000000000000000000000000000000000000000000000000abcd, 0, 0] };
    y[2] = BigNum { limbs: [0x0000000000000000000000000000000000000000000000000000000000000069, 0, 0] };

    main(z, y);
    // Uncomment to make test fail
    // main(1, 1);
}

// #[test]
// fn test_main_again() {
//     let c = main(21888242871839275222246405745257275088548364400416034343698204186575808495616, 21888242871839275222246405745257275088548364400416034343698204186575808495616);

//     assert(c == 4886695622894899639804758159951353694468790955993068545941373991772988819618);
//     // Uncomment to make test fail
//     // main(1, 1);
// }
