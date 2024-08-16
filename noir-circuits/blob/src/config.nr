use dep::bigint::{BigNum, fields::bls12_381Fr::BLS12_381_Fr_Params};

type F = BigNum<3, BLS12_381_Fr_Params>;

global FIELDS_PER_BLOB: u64 = 4096;
global LOG_FIELDS_PER_BLOB: u64 = 12;
global EXTRA_FIELDS_PER_BLOB: u64 = 16; // 16 = floor(4096 FIELDS_PER_BLOB / 254 noir_field_bits), wasting only 32 bits. 
global NOIR_FIELDS_PER_BLOB: u64 = FIELDS_PER_BLOB + EXTRA_FIELDS_PER_BLOB;
global FIELDS_CARRYING_AN_EXTRA_BIT_PER_BLOB: u64 = EXTRA_FIELDS_PER_BLOB * 254; // EXTRA_FIELDS_PER_BLOB * 254 = 4064. So the first 4064 bls Fr fields in the blob will carry an extra bit in their 255th bit position, that will be used to reconstitute 16 extra fields.
