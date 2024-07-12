use dep::bigint::{BigNum, fields::bls12381Fr::Bls12_381_Fr_Params};

type F = BigNum<3, Bls12_381_Fr_Params>;

global FIELDS_PER_BLOB: u64 = 8; // actually 4096
global LOG_FIELDS_PER_BLOB: u64 = 3; // actually 12
// global D_LIMBS_SLICE: [Field] = 
global D: F = BigNum { limbs: [8, 0, 0] };
global D_INV = D.__invmod(); // TODO: actual value

global ROOTS: [F; FIELDS_PER_BLOB] = [ 
    BigNum { limbs: [ 0x000000000000000000000000000001, 0x000000000000000000000000000000, 0x000000 ] } ,
    BigNum { limbs: [ 0xbda402fffe5bfeffffffff00000000, 0xa753299d7d483339d80809a1d80553, 0x0073ed ] } ,
    BigNum { limbs: [ 0x030002760300000001000000000000, 0x0000000000008d51ccce760304d0ec, 0x000000 ] } ,
    BigNum { limbs: [ 0xbaa40089fb5bfefffeffff00000001, 0xa753299d7d47a5e80b39939ed33467, 0x0073ed ] } ,
    BigNum { limbs: [ 0x8b21c28713b7007228fd3397743f7a, 0x66f603fa66e78c0625cd70d77ce2b3, 0x003457 ] } ,
    BigNum { limbs: [ 0x32824078eaa4fe8dd702cb688bc087, 0x405d25a31660a733b23a98ca5b22a0, 0x003f96 ] } ,
    BigNum { limbs: [ 0x74903694b04fd86037fe81ae99502e, 0xb22e5ce11044babc5affca86bf658e, 0x001333 ] } ,
    BigNum { limbs: [ 0x4913cc6b4e0c269fc8017d5166afd3, 0xf524ccbc6d03787d7d083f1b189fc5, 0x0060b9 ] }
];