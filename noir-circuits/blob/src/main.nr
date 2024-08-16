// BIG CONFIG *********************************************************************

mod config;

use crate::{
    config::{
    BigNum, BLS12_381_Fr_Params, F, FIELDS_PER_BLOB, LOG_FIELDS_PER_BLOB, NOIR_FIELDS_PER_BLOB,
    FIELDS_CARRYING_AN_EXTRA_BIT_PER_BLOB
}
};

//*********************************************************************************

use std::hash::poseidon2;

global LIMB_MAX = 2.pow_32(120);
global TWO_POW_255 = 2.pow_32(255);

// DANGER: this assumes the input bignum is <= the Noir field size.
// Only use this if you _know_ the data being passed in is small enough.
//
// Or actually, maybe it's not unsafe, if Field catches overflows?
fn unsafe_bignum_to_field(x: F) -> Field {
    let mut result: Field = 0;
    result += x.limbs[3 - 1];
    for i in 1..3 {
        result *= LIMB_MAX;
        result += x.limbs[3 - i - 1];
    }
    result
}

unconstrained fn __unsafe_extract_top_bit(x: F) -> (Field, F) {
    let top_limb: Field = x.limbs[2];
    // The top_limb is at most 2 bytes (16 bits).
    // 0x8000 = 2^15 = 32768
    let top_bit: Field = (top_limb as u16 / 0x8000) as Field;
    let top_limb_with_top_bit_removed = top_limb - top_bit * 0x8000;
    let x_with_top_bit_removed: F = BigNum { limbs: [x.limbs[0], x.limbs[1], top_limb_with_top_bit_removed] };
    (top_bit, x_with_top_bit_removed)
}

// DANGER: it's named as "unsafe" because the caller MUST already have checked that 
// each blob Field is formatted as (u1, Field). I.e. the "rhs" 254-bits should already
// fit within a Field. If the "rhs" 254 bits is larger than the field modulus,
// there will be an uncaught overflow of the 254-bits in the Field, resulting in 
// an unintended tiny value.
//
// For efficiency, the top_bit is kept as a Field throughout.
fn unsafe_extract_top_bit(x: F) -> (Field, F) {
    let (top_bit, x_with_top_bit_removed) = __unsafe_extract_top_bit(x);
    assert_eq(top_bit * 0x8000 + x_with_top_bit_removed.limbs[2], x.limbs[2]);
    assert_eq(x_with_top_bit_removed.limbs[1], x.limbs[1]); // BUG: this should be free; it's currently contributing 4k constraints
    assert_eq(x_with_top_bit_removed.limbs[0], x.limbs[0]); // BUG: this should be free; it's currently contributing 4k constraints

    (top_bit, x_with_top_bit_removed)
}

fn blob_to_fields__tightly_packed(blob: [F; FIELDS_PER_BLOB]) -> [Field; NOIR_FIELDS_PER_BLOB] {
    let mut blob_as_fields: [Field; NOIR_FIELDS_PER_BLOB] = [0; NOIR_FIELDS_PER_BLOB];
    let mut top_bits: [Field; FIELDS_CARRYING_AN_EXTRA_BIT_PER_BLOB] = [0; FIELDS_CARRYING_AN_EXTRA_BIT_PER_BLOB];
    for i in 0..FIELDS_CARRYING_AN_EXTRA_BIT_PER_BLOB {
        let (top_bit, field_with_top_bit_removed): (Field, F) = unsafe_extract_top_bit(blob[i]);
        top_bits[i] = top_bit;
        blob_as_fields[i] = unsafe_bignum_to_field(field_with_top_bit_removed);
    }
    for i in FIELDS_CARRYING_AN_EXTRA_BIT_PER_BLOB..FIELDS_PER_BLOB {
        blob_as_fields[i] = unsafe_bignum_to_field(blob[i]);
    }
    for i in FIELDS_PER_BLOB..NOIR_FIELDS_PER_BLOB {
        // the top_bits are assumed to be big-endian bit arrays:
        let mut reconstituted_field = top_bits[0];
        for j in 1..254 {
            let k = i * 254 + j;
            reconstituted_field *= 2;
            reconstituted_field += top_bits[k]; // BUG: k is known at compile-time, so this shouldn't be contributing 24k constraints?
            std::as_witness(reconstituted_field); // BUG: this is costing 4048 gates
        }
        blob_as_fields[i] = reconstituted_field;
    }
    blob_as_fields
}

fn main(blob: [F; FIELDS_PER_BLOB]) -> pub [Field; NOIR_FIELDS_PER_BLOB] {
    blob_to_fields__tightly_packed(blob)
}
