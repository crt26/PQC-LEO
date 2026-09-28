# Supported PQC Algorithms <!-- omit from toc -->

## Support Overview <!-- omit from toc -->
This document outlines the Key Encapsulation Mechanisms (KEMs) and digital signature algorithms supported by this project, based on its upstream cryptographic dependencies: Liboqs, OQS-Provider, and OpenSSL. While the PQC-LEO project integrates nearly all algorithms from these libraries, there are a few exceptions.

It contains comprehensive lists of all supported PQC algorithms, along with any exclusions and the rationale behind them.

> **Notice:** If you use the --latest-dependency-versions flag with the main setup script to pull the most recent versions of the OQS libraries, the supported algorithms may differ from what is documented here. This documentation reflects support based on the last tested versions of the dependencies and may not be accurate for upstream updates.

## Contents <!-- omit from toc -->
- [Dependency Usage by Testing Category](#dependency-usage-by-testing-category)
- [Liboqs Algorithms](#liboqs-algorithms)
  - [Algorithm Support Summary](#algorithm-support-summary)
  - [Supported KEM Algorithms](#supported-kem-algorithms)
  - [Supported Digital Signature Algorithms](#supported-digital-signature-algorithms)
- [OpenSSL Algorithms](#openssl-algorithms)
  - [Algorithm Support Summary](#algorithm-support-summary-1)
  - [Supported KEM Algorithms](#supported-kem-algorithms-1)
  - [Supported Digital Signature Algorithms](#supported-digital-signature-algorithms-1)
  - [Supported Classical Algorithms](#supported-classical-algorithms)
- [OQS-Provider Algorithms](#oqs-provider-algorithms)
  - [Algorithm Support Summary](#algorithm-support-summary-2)
  - [Supported KEM Algorithms](#supported-kem-algorithms-2)
  - [Supported Digital Signature Algorithms](#supported-digital-signature-algorithms-2)
- [External Documentation](#external-documentation)

## Dependency Usage by Testing Category
Different testing categories within this project rely on distinct combinations of upstream cryptographic dependencies. The table below summarises which libraries are used in each context:

| **Testing Category**              | **Dependencies Used**       |
|-----------------------------------|-----------------------------|
| Computational Performance Testing | Liboqs                      |
| TLS Handshake Testing             | OpenSSL 3.6.1, OQS-Provider |
| OpenSSL speed Benchmarking        | OpenSSL 3.6.1, OQS-Provider |

Although the OQS-Provider depends on Liboqs for algorithm implementations, it exposes a different set of algorithms. As such, its supported algorithms are documented separately in this guide.

Each testing category also provides support for energy usage evaluations. However, there are some algorithms that are not supported for this, and any exclusions are discussed in the relevant sections.

## Liboqs Algorithms

### Algorithm Support Summary
The PQC-LEO project supports all key encapsulation mechanisms (KEMs) and digital signature algorithms provided by Liboqs, with two notable exceptions:

- **Falcon** digital signature variants are not compatible with **memory profiling on ARM systems** due to issues between the scheme’s structure and the Valgrind Massif tool. This does not affect general functional testing or result parsing, which remain fully supported across all platforms.

- **Stateful signature schemes (XMSS and LMS)** are currently excluded from this project. Although Liboqs supports them, they are disabled by default and require hazardous experimental build flags to enable key generation and signing. These schemes are not part of the NIST standardisation process, and Liboqs explicitly warns that support may be removed in future releases if misused. Their inclusion within this project may be reconsidered in a future release if justified.

All Liboqs algorithms listed below are also supported for computational energy usage testing. Information presented in the tables below on algorithm specifications are taken from the algorithm spec sheets included in the [Liboqs v0.16.0 documentation](https://github.com/open-quantum-safe/liboqs/tree/5a1a854b0dc9f2141bdc771c555ee60c37950183/docs/algorithms).

In addition to standard algorithm implementations, Liboqs offers memory optimised implementations, where available upstream, which offer reduced memory footprint at the cost of performance. To utilise this feature, users can enable memory optimisation during the setup process. These implementations are disabled by default but can be enabled by passing the `--liboqs-memory-optimisation` flag to the setup script. For more information, please see the [Advanced Setup Configuration Guide](./advanced_setup_configuration.md).

For further context and guidance:

- See the [Advanced Setup Configuration Guide](./advanced_setup_configuration.md) for advanced setup options.
- Refer to the [Disclaimer Document](../DISCLAIMER.md) for security warnings and usage guidance.

### Supported KEM Algorithms

| **Algorithm Name**        | **Claimed NIST Level** | **Public key size (bytes)** | **Secret key size (bytes)** | **Ciphertext size (bytes)** | **Shared secret size (bytes)** | **Keypair seed size (bytes)** | **Encapsulation seed size (bytes)** |
|---------------------------|------------------------|-----------------------------|-----------------------------|-----------------------------|--------------------------------|-------------------------------|-------------------------------------|
| BIKE-L1                   |            1           |                        1541 |                        5223 |                        1573 |                             32 |                           n/a |                                 n/a |
| BIKE-L3                   |            3           |                        3083 |                       10105 |                        3115 |                             32 |                           n/a |                                 n/a |
| BIKE-L5                   |            5           |                        5122 |                       16494 |                        5154 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-348864   |            1           |                      261120 |                        6492 |                          96 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-348864f  |            1           |                      261120 |                        6492 |                          96 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-460896   |            3           |                      524160 |                       13608 |                         156 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-460896f  |            3           |                      524160 |                       13608 |                         156 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-6688128  |            5           |                     1044992 |                       13932 |                         208 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-6688128f |            5           |                     1044992 |                       13932 |                         208 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-6960119  |            5           |                     1047319 |                       13948 |                         194 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-6960119f |            5           |                     1047319 |                       13948 |                         194 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-8192128  |            5           |                     1357824 |                       14120 |                         208 |                             32 |                           n/a |                                 n/a |
| Classic-McEliece-8192128f |            5           |                     1357824 |                       14120 |                         208 |                             32 |                           n/a |                                 n/a |
| FrodoKEM-640-AES          |            1           |                        9616 |                       19888 |                        9752 |                             16 |                           n/a |                                 n/a |
| FrodoKEM-640-SHAKE        |            1           |                        9616 |                       19888 |                        9752 |                             16 |                           n/a |                                 n/a |
| FrodoKEM-976-AES          |            3           |                       15632 |                       31296 |                       15792 |                             24 |                           n/a |                                 n/a |
| FrodoKEM-976-SHAKE        |            3           |                       15632 |                       31296 |                       15792 |                             24 |                           n/a |                                 n/a |
| FrodoKEM-1344-AES         |            5           |                       21520 |                       43088 |                       21696 |                             32 |                           n/a |                                 n/a |
| FrodoKEM-1344-SHAKE       |            5           |                       21520 |                       43088 |                       21696 |                             32 |                           n/a |                                 n/a |
| eFrodoKEM-640-AES         |            1           |                        9616 |                       19888 |                        9720 |                             16 |                           n/a |                                 n/a |
| eFrodoKEM-640-SHAKE       |            1           |                        9616 |                       19888 |                        9720 |                             16 |                           n/a |                                 n/a |
| eFrodoKEM-976-AES         |            3           |                       15632 |                       31296 |                       15744 |                             24 |                           n/a |                                 n/a |
| eFrodoKEM-976-SHAKE       |            3           |                       15632 |                       31296 |                       15744 |                             24 |                           n/a |                                 n/a |
| eFrodoKEM-1344-AES        |            5           |                       21520 |                       43088 |                       21632 |                             32 |                           n/a |                                 n/a |
| eFrodoKEM-1344-SHAKE      |            5           |                       21520 |                       43088 |                       21632 |                             32 |                           n/a |                                 n/a |
| HQC-1                     |            1           |                        2241 |                        2321 |                        4433 |                             32 |                           n/a |                                 n/a |
| HQC-3                     |            3           |                        4514 |                        4602 |                        8978 |                             32 |                           n/a |                                 n/a |
| HQC-5                     |            5           |                        7237 |                        7333 |                       14421 |                             32 |                           n/a |                                 n/a |
| Kyber512                  |            1           |                         800 |                        1632 |                         768 |                             32 |                           n/a |                                 n/a |
| Kyber768                  |            3           |                        1184 |                        2400 |                        1088 |                             32 |                           n/a |                                 n/a |
| Kyber1024                 |            5           |                        1568 |                        3168 |                        1568 |                             32 |                           n/a |                                 n/a |
| ML-KEM-512                |            1           |                         800 |                        1632 |                         768 |                             32 |                            64 |                                  32 |
| ML-KEM-768                |            3           |                        1184 |                        2400 |                        1088 |                             32 |                            64 |                                  32 |
| ML-KEM-1024               |            5           |                        1568 |                        3168 |                        1568 |                             32 |                            64 |                                  32 |
| NTRU-HPS-2048-509         |            1           |                         699 |                         935 |                         699 |                             32 |                           n/a |                                 n/a |
| NTRU-HPS-2048-677         |            3           |                         930 |                        1234 |                         930 |                             32 |                           n/a |                                 n/a |
| NTRU-HPS-4096-821         |            5           |                        1230 |                        1590 |                        1230 |                             32 |                           n/a |                                 n/a |
| NTRU-HPS-4096-1229        |            5           |                        1842 |                        2366 |                        1842 |                             32 |                           n/a |                                 n/a |
| NTRU-HRSS-701             |            3           |                        1138 |                        1450 |                        1138 |                             32 |                           n/a |                                 n/a |
| NTRU-HRSS-1373            |            5           |                        2401 |                        2983 |                        2401 |                             32 |                           n/a |                                 n/a |
| sntrup761                 |            2           |                        1158 |                        1763 |                        1039 |                             32 |                           n/a |                                 n/a |

### Supported Digital Signature Algorithms

| **Algorithm Name**                      | **Claimed NIST Level** | **Public key size (bytes)** | **Secret key size (bytes)** | **Signature size (bytes)** |
|-----------------------------------------|------------------------|-----------------------------|-----------------------------|----------------------------|
| cross-rsdp-128-balanced                 |            1           |                          77 |                          32 |                      13152 |
| cross-rsdp-128-fast                     |            1           |                          77 |                          32 |                      18432 |
| cross-rsdp-128-small                    |            1           |                          77 |                          32 |                      12432 |
| cross-rsdp-192-balanced                 |            3           |                         115 |                          48 |                      29853 |
| cross-rsdp-192-fast                     |            3           |                         115 |                          48 |                      41406 |
| cross-rsdp-192-small                    |            3           |                         115 |                          48 |                      28391 |
| cross-rsdp-256-balanced                 |            5           |                         153 |                          64 |                      53527 |
| cross-rsdp-256-fast                     |            5           |                         153 |                          64 |                      74590 |
| cross-rsdp-256-small                    |            5           |                         153 |                          64 |                      50818 |
| cross-rsdpg-128-balanced                |            1           |                          54 |                          32 |                       9120 |
| cross-rsdpg-128-fast                    |            1           |                          54 |                          32 |                      11980 |
| cross-rsdpg-128-small                   |            1           |                          54 |                          32 |                       8960 |
| cross-rsdpg-192-balanced                |            3           |                          83 |                          48 |                      22464 |
| cross-rsdpg-192-fast                    |            3           |                          83 |                          48 |                      26772 |
| cross-rsdpg-192-small                   |            3           |                          83 |                          48 |                      20452 |
| cross-rsdpg-256-balanced                |            5           |                         106 |                          64 |                      40100 |
| cross-rsdpg-256-fast                    |            5           |                         106 |                          64 |                      48102 |
| cross-rsdpg-256-small                   |            5           |                         106 |                          64 |                      36454 |
| Falcon-512                              |            1           |                         897 |                        1281 |                        752 |
| Falcon-1024                             |            5           |                        1793 |                        2305 |                       1462 |
| Falcon-padded-512                       |            1           |                         897 |                        1281 |                        666 |
| Falcon-padded-1024                      |            5           |                        1793 |                        2305 |                       1280 |
| MAYO-1                                  |            1           |                        1420 |                          24 |                        454 |
| MAYO-2                                  |            1           |                        4912 |                          24 |                        186 |
| MAYO-3                                  |            3           |                        2986 |                          32 |                        681 |
| MAYO-5                                  |            5           |                        5554 |                          40 |                        964 |
| ML-DSA-44                               |            2           |                        1312 |                        2560 |                       2420 |
| ML-DSA-65                               |            3           |                        1952 |                        4032 |                       3309 |
| ML-DSA-87                               |            5           |                        2592 |                        4896 |                       4627 |
| mqom2_cat1_gf16_fast_r5                 |            1           |                          60 |                          88 |                       3280 |
| mqom2_cat1_gf16_fast_r3                 |            1           |                          60 |                          88 |                       3484 |
| mqom2_cat1_gf16_short_r5                |            1           |                          60 |                          88 |                       2916 |
| mqom2_cat1_gf16_short_r3                |            1           |                          60 |                          88 |                       3060 |
| mqom2_cat3_gf16_fast_r5                 |            3           |                          90 |                         132 |                       7738 |
| mqom2_cat3_gf16_fast_r3                 |            3           |                          90 |                         132 |                       8224 |
| mqom2_cat3_gf16_short_r5                |            3           |                          90 |                         132 |                       6496 |
| mqom2_cat3_gf16_short_r3                |            3           |                          90 |                         132 |                       6820 |
| mqom2_cat5_gf16_fast_r5                 |            5           |                         122 |                         180 |                      13772 |
| mqom2_cat5_gf16_fast_r3                 |            5           |                         122 |                         180 |                      14708 |
| mqom2_cat5_gf16_short_r5                |            5           |                         122 |                         180 |                      12014 |
| mqom2_cat5_gf16_short_r3                |            5           |                         122 |                         180 |                      12664 |
| SLH_DSA_PURE_SHA2_128S                  |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_PURE_SHA2_128F                  |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_PURE_SHA2_192S                  |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_PURE_SHA2_192F                  |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_PURE_SHA2_256S                  |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_PURE_SHA2_256F                  |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_PURE_SHAKE_128S                 |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_PURE_SHAKE_128F                 |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_PURE_SHAKE_192S                 |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_PURE_SHAKE_192F                 |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_PURE_SHAKE_256S                 |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_PURE_SHAKE_256F                 |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_224_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_256_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_384_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_512_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_512_224_PREHASH_SHA2_128S  |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_512_256_PREHASH_SHA2_128S  |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_224_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_256_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_384_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_512_PREHASH_SHA2_128S      |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHAKE_128_PREHASH_SHA2_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHAKE_256_PREHASH_SHA2_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_224_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_256_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_384_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_512_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_512_224_PREHASH_SHA2_128F  |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_512_256_PREHASH_SHA2_128F  |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_224_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_256_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_384_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_512_PREHASH_SHA2_128F      |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHAKE_128_PREHASH_SHA2_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHAKE_256_PREHASH_SHA2_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_224_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_256_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_384_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_512_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_512_224_PREHASH_SHA2_192S  |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_512_256_PREHASH_SHA2_192S  |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_224_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_256_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_384_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_512_PREHASH_SHA2_192S      |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHAKE_128_PREHASH_SHA2_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHAKE_256_PREHASH_SHA2_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_224_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_256_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_384_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_512_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_512_224_PREHASH_SHA2_192F  |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_512_256_PREHASH_SHA2_192F  |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_224_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_256_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_384_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_512_PREHASH_SHA2_192F      |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHAKE_128_PREHASH_SHA2_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHAKE_256_PREHASH_SHA2_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_224_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_256_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_384_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_512_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_512_224_PREHASH_SHA2_256S  |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_512_256_PREHASH_SHA2_256S  |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_224_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_256_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_384_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_512_PREHASH_SHA2_256S      |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHAKE_128_PREHASH_SHA2_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHAKE_256_PREHASH_SHA2_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_224_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_256_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_384_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_512_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_512_224_PREHASH_SHA2_256F  |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_512_256_PREHASH_SHA2_256F  |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_224_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_256_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_384_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_512_PREHASH_SHA2_256F      |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHAKE_128_PREHASH_SHA2_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHAKE_256_PREHASH_SHA2_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_224_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_256_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_384_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_512_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_512_224_PREHASH_SHAKE_128S |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_512_256_PREHASH_SHAKE_128S |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_224_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_256_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_384_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA3_512_PREHASH_SHAKE_128S     |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHAKE_128_PREHASH_SHAKE_128S    |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHAKE_256_PREHASH_SHAKE_128S    |            1           |                          32 |                          64 |                       7856 |
| SLH_DSA_SHA2_224_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_256_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_384_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_512_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_512_224_PREHASH_SHAKE_128F |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_512_256_PREHASH_SHAKE_128F |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_224_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_256_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_384_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA3_512_PREHASH_SHAKE_128F     |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHAKE_128_PREHASH_SHAKE_128F    |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHAKE_256_PREHASH_SHAKE_128F    |            1           |                          32 |                          64 |                      17088 |
| SLH_DSA_SHA2_224_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_256_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_384_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_512_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_512_224_PREHASH_SHAKE_192S |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_512_256_PREHASH_SHAKE_192S |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_224_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_256_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_384_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA3_512_PREHASH_SHAKE_192S     |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHAKE_128_PREHASH_SHAKE_192S    |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHAKE_256_PREHASH_SHAKE_192S    |            3           |                          48 |                          96 |                      16224 |
| SLH_DSA_SHA2_224_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_256_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_384_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_512_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_512_224_PREHASH_SHAKE_192F |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_512_256_PREHASH_SHAKE_192F |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_224_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_256_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_384_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA3_512_PREHASH_SHAKE_192F     |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHAKE_128_PREHASH_SHAKE_192F    |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHAKE_256_PREHASH_SHAKE_192F    |            3           |                          48 |                          96 |                      35664 |
| SLH_DSA_SHA2_224_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_256_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_384_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_512_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_512_224_PREHASH_SHAKE_256S |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_512_256_PREHASH_SHAKE_256S |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_224_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_256_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_384_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA3_512_PREHASH_SHAKE_256S     |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHAKE_128_PREHASH_SHAKE_256S    |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHAKE_256_PREHASH_SHAKE_256S    |            5           |                          64 |                         128 |                      29792 |
| SLH_DSA_SHA2_224_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_256_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_384_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_512_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_512_224_PREHASH_SHAKE_256F |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA2_512_256_PREHASH_SHAKE_256F |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_224_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_256_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_384_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHA3_512_PREHASH_SHAKE_256F     |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHAKE_128_PREHASH_SHAKE_256F    |            5           |                          64 |                         128 |                      49856 |
| SLH_DSA_SHAKE_256_PREHASH_SHAKE_256F    |            5           |                          64 |                         128 |                      49856 |
| SNOVA_24_5_4                            |            1           |                        1016 |                          48 |                        248 |
| SNOVA_24_5_4_SHAKE                      |            1           |                        1016 |                          48 |                        248 |
| SNOVA_24_5_4_esk                        |            1           |                        1016 |                       36848 |                        248 |
| SNOVA_24_5_4_SHAKE_esk                  |            1           |                        1016 |                       36848 |                        248 |
| SNOVA_37_17_2                           |            1           |                        9842 |                          48 |                        124 |
| SNOVA_25_8_3                            |            1           |                        2320 |                          48 |                        165 |
| SNOVA_56_25_2                           |            3           |                       31266 |                          48 |                        178 |
| SNOVA_49_11_3                           |            3           |                        6006 |                          48 |                        286 |
| SNOVA_37_8_4                            |            3           |                        4112 |                          48 |                        376 |
| SNOVA_24_5_5                            |            3           |                        1579 |                          48 |                        379 |
| SNOVA_60_10_4                           |            5           |                        8016 |                          48 |                        576 |
| SNOVA_29_6_5                            |            5           |                        2716 |                          48 |                        454 |
| OV-Is                                   |            1           |                      412160 |                      348704 |                         96 |
| OV-Ip                                   |            1           |                      278432 |                      237896 |                        128 |
| OV-III                                  |            3           |                     1225440 |                     1044320 |                        200 |
| OV-V                                    |            5           |                     2869440 |                     2436704 |                        260 |
| OV-Is-pkc                               |            1           |                       66576 |                      348704 |                         96 |
| OV-Ip-pkc                               |            1           |                       43576 |                      237896 |                        128 |
| OV-III-pkc                              |            3           |                      189232 |                     1044320 |                        200 |
| OV-V-pkc                                |            5           |                      446992 |                     2436704 |                        260 |
| OV-Is-pkc-skc                           |            1           |                       66576 |                          32 |                         96 |
| OV-Ip-pkc-skc                           |            1           |                       43576 |                          32 |                        128 |
| OV-III-pkc-skc                          |            3           |                      189232 |                          32 |                        200 |
| OV-V-pkc-skc                            |            5           |                      446992 |                          32 |                        260 |

## OpenSSL Algorithms

### Algorithm Support Summary
OpenSSL 3.6.1 includes native support for the NIST-standardised PQC algorithms **ML-KEM**, **ML-DSA**, and **SLH-DSA**. This project integrates these algorithms for TLS benchmarking where possible. However, some limitations affect their usage in performance testing and handshake scenarios:

#### Known Limitations
- **SLH-DSA** is currently not supported by the OpenSSL `speed` utility, making it unavailable for cryptographic performance benchmarking.

- **SLH-DSA** while supported at the provider level (e.g., for certificate generation), has not yet been integrated into OpenSSL's TLS stack (`s_client`, `s_server`, `speed`). Its inclusion in TLS 1.3 is under consideration via this [IETF draft](https://datatracker.ietf.org/doc/html/draft-reddy-tls-slhdsa-01). Until then, SPHINCS+ from the OQS-Provider will be used as a placeholder for stateless hash-based signatures in TLS tests.
  
- The **X448MLKEM1024** Hybrid-PQC KEM is implemented and supported by OpenSSL's `speed` tool, but not registered as a TLS group. It is excluded from handshake testing, though it remains available for TLS speed testing within this project.

#### Classical Algorithm Benchmarks
To provide performance baselines for comparison, classical algorithms are also included in TLS benchmarking:

- RSA-2048, RSA-3072, RSA-4096
- prime256v1, secp384r1, secp521r1

These schemes help assess the overhead and feasibility of PQC adoption in real-world contexts.

#### Supported Algorithms for Energy Usage Evaluations
Algorithms provided by OpenSSL that are used within standard TLS handshake and TLS speed testing are also supported for energy usage evaluation testing. However, there are the following exceptions for Hybrid-PQC TLS speed energy usage testing. This is due to the current version of OpenSSL not providing encoding paths for the Hybrid-PQC KEM algorithms, preventing key export and file-based cryptographic operations required by the benchmarking process. This will continue to be reviewed in future releases of PQC-LEO to provide support for these algorithms in energy usage testing where possible.

**Unsupported Algorithms for TLS Speed Energy Usage Testing:**
- X25519MLKEM768
- X448MLKEM1024
- SecP256r1MLKEM768
- SecP384r1MLKEM1024

### Supported KEM Algorithms

| **Algorithm Name** | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** |
|--------------------|:------------------------:|:----------------------------------:|:----------------------------------:|
| MLKEM512           |                          |                  *                 |                  *                 |
| MLKEM768           |                          |                  *                 |                  *                 |
| MLKEM1024          |                          |                  *                 |                  *                 |
| X25519MLKEM768     |             *            |                  *                 |                  *                 |
| X448MLKEM1024      |             *            |                                    |                  *                 |
| SecP256r1MLKEM768  |             *            |                  *                 |                  *                 |
| SecP384r1MLKEM1024 |             *            |                  *                 |                  *                 |

### Supported Digital Signature Algorithms

| **Algorithm Name** | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** |
|--------------------|:------------------------:|:----------------------------------:|:----------------------------------:|
| MLDSA44            |                          |                  *                 |                  *                 |
| MLDSA65            |                          |                  *                 |                  *                 |
| MLDSA87            |                          |                  *                 |                  *                 |

### Supported Classical Algorithms

| **Algorithm Name** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** |
|--------------------|:----------------------------------:|:----------------------------------:|
| RSA-2048           |                  *                 |                  *                 |
| RSA-3072           |                  *                 |                  *                 |
| RSA-4096           |                  *                 |                  *                 |
| prime256v1         |                  *                 |                  *                 |
| secp384r1          |                  *                 |                  *                 |
| secp521r1          |                  *                 |                  *                 |

## OQS-Provider Algorithms

### Algorithm Support Summary
The majority of algorithms provided by the OQS-Provider are supported by this project for automated TLS handshake and TLS speed benchmarking. However, a few exceptions exist due to known limitations in protocol compliance or tool compatibility.

#### Known TLS Handshake Testing Limitations
Certain variations of the supported digital signature schemes are excluded from TLS handshake testing due to non-compliance with [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446), which defines the specifications of the TLS 1.3 protocol. These include:

- **UOV Scheme Variations**
- **SNOVA Scheme Variations**
- **CROSSrsdp256small**

These schemes remain available for use in the TLS speed tests that the PQC-LEO provides using the OpenSSL `speed` tool. 

Whilst a significant number of these scheme variations can not be used in TLS Handshake testing, there are the following exceptions:

| **Scheme** | **Variations Supported for TLS Handshake Testing**                                                                                            |
|------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| UOV         | OV_Ip_pkc, p256_OV_Ip_pkc, OV_Ip_pkc_skc, p256_OV_Ip_pkc_skc                                                                                  |
| SNOVA      | snova2454, p256_snova2454, snova2454esk, p256_snova2454esk, snova37172, p256_snova37172, snova2455, p384_snova2455, snova2965, p521_snova2965 |
| CROSSrsdp  | CROSSrsdp256small                                                                                                                             |

#### OpenSSL 3.6.1 Compatibility
With native support of various PQC algorithms in OpenSSL 3.6.1, the OQS-Provider library automatically disables its implementations of overlapping algorithms (e.g., ML-KEM, ML-DSA, SLH-DSA) to prevent provider conflicts during initialisation. For more information, see the relevant OQS-Provider documentation below.

#### Supported Algorithms for Energy Usage Testing
All algorithms supported for TLS handshake and speed testing are also supported for their corresponding energy usage tests.

#### Additional Information
For further details on algorithm support, compatibility, or enabling OQS-Provider algorithms suppourted by PQC-LEO that are disabled by default, see:

- [OQS-Provider Notice](https://github.com/open-quantum-safe/oqs-provider/tree/1670a8a91bbca997d33e6b6851309d6241cc224c#35-and-greater)
- [Advanced Setup Configuration Guide](./advanced_setup_configuration.md)
- [README - Choosing Installation Mode](../README.md#choosing-installation-mode)
- [Disclaimer Document](../DISCLAIMER.md)

### Supported KEM Algorithms

| **Algorithm Name**    | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** | **Requires Enabling (*)** |
|-----------------------|--------------------------|------------------------------------|------------------------------------|---------------------------|
| bikel1                |                          |                  *                 |                  *                 |             *             |
| bikel3                |                          |                  *                 |                  *                 |                           |
| bikel5                |                          |                  *                 |                  *                 |                           |
| p256_bikel1           |             *            |                  *                 |                  *                 |             *             |
| x25519_bikel1         |             *            |                  *                 |                  *                 |             *             |
| p384_bikel3           |             *            |                  *                 |                  *                 |                           |
| x448_bikel3           |             *            |                  *                 |                  *                 |                           |
| p521_bikel5           |             *            |                  *                 |                  *                 |                           |
| efrodo640aes          |                          |                  *                 |                  *                 |                           |
| efrodo640shake        |                          |                  *                 |                  *                 |                           |
| efrodo976aes          |                          |                  *                 |                  *                 |                           |
| efrodo976shake        |                          |                  *                 |                  *                 |                           |
| efrodo1344aes         |                          |                  *                 |                  *                 |                           |
| efrodo1344shake       |                          |                  *                 |                  *                 |                           |
| p256_efrodo640aes     |             *            |                  *                 |                  *                 |                           |
| x25519_efrodo640aes   |             *            |                  *                 |                  *                 |                           |
| p256_efrodo640shake   |             *            |                  *                 |                  *                 |                           |
| x25519_efrodo640shake |             *            |                  *                 |                  *                 |                           |
| p384_efrodo976aes     |             *            |                  *                 |                  *                 |                           |
| x448_efrodo976aes     |             *            |                  *                 |                  *                 |                           |
| p384_efrodo976shake   |             *            |                  *                 |                  *                 |                           |
| x448_efrodo976shake   |             *            |                  *                 |                  *                 |                           |
| p521_efrodo1344aes    |             *            |                  *                 |                  *                 |                           |
| p521_efrodo1344shake  |             *            |                  *                 |                  *                 |                           |
| frodo640aes           |                          |                  *                 |                  *                 |                           |
| frodo640shake         |                          |                  *                 |                  *                 |                           |
| frodo976aes           |                          |                  *                 |                  *                 |                           |
| frodo976shake         |                          |                  *                 |                  *                 |                           |
| frodo1344aes          |                          |                  *                 |                  *                 |                           |
| frodo1344shake        |                          |                  *                 |                  *                 |                           |
| p256_frodo640aes      |             *            |                  *                 |                  *                 |                           |
| x25519_frodo640aes    |             *            |                  *                 |                  *                 |                           |
| p256_frodo640shake    |             *            |                  *                 |                  *                 |                           |
| x25519_frodo640shake  |             *            |                  *                 |                  *                 |                           |
| p384_frodo976aes      |             *            |                  *                 |                  *                 |                           |
| x448_frodo976aes      |             *            |                  *                 |                  *                 |                           |
| p384_frodo976shake    |             *            |                  *                 |                  *                 |                           |
| x448_frodo976shake    |             *            |                  *                 |                  *                 |                           |
| p521_frodo1344aes     |             *            |                  *                 |                  *                 |                           |
| p521_frodo1344shake   |             *            |                  *                 |                  *                 |                           |
| hqc1                  |                          |                  *                 |                  *                 |                           |
| hqc3                  |                          |                  *                 |                  *                 |                           |
| hqc5                  |                          |                  *                 |                  *                 |                           |
| p256_hqc1             |             *            |                  *                 |                  *                 |                           |
| x25519_hqc1           |             *            |                  *                 |                  *                 |                           |
| p384_hqc3             |             *            |                  *                 |                  *                 |                           |
| x448_hqc3             |             *            |                  *                 |                  *                 |                           |
| p521_hqc5             |             *            |                  *                 |                  *                 |                           |
| p256_mlkem512         |             *            |                  *                 |                  *                 |                           |
| x25519_mlkem512       |             *            |                  *                 |                  *                 |                           |
| bp256_mlkem512        |             *            |                  *                 |                  *                 |                           |
| p384_mlkem768         |             *            |                  *                 |                  *                 |                           |
| x448_mlkem768         |             *            |                  *                 |                  *                 |                           |
| bp384_mlkem768        |             *            |                  *                 |                  *                 |                           |
| p521_mlkem1024        |             *            |                  *                 |                  *                 |                           |
| bp512_mlkem1024       |             *            |                  *                 |                  *                 |                           |

### Supported Digital Signature Algorithms

| **Algorithm Name**        | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** | **Requires Enabling (*)** |
|---------------------------|--------------------------|------------------------------------|------------------------------------|---------------------------|
| p256_mldsa44              |             *            |                  *                 |                  *                 |                           |
| rsa3072_mldsa44           |             *            |                  *                 |                  *                 |                           |
| p384_mldsa65              |             *            |                  *                 |                  *                 |                           |
| p521_mldsa87              |             *            |                  *                 |                  *                 |                           |
| falcon512                 |                          |                  *                 |                  *                 |                           |
| falconpadded512           |                          |                  *                 |                  *                 |                           |
| falcon1024                |                          |                  *                 |                  *                 |                           |
| falconpadded1024          |                          |                  *                 |                  *                 |                           |
| p256_falcon512            |             *            |                  *                 |                  *                 |                           |
| rsa3072_falcon512         |             *            |                  *                 |                  *                 |                           |
| p256_falconpadded512      |             *            |                  *                 |                  *                 |                           |
| rsa3072_falconpadded512   |             *            |                  *                 |                  *                 |                           |
| p521_falcon1024           |             *            |                  *                 |                  *                 |                           |
| p521_falconpadded1024     |             *            |                  *                 |                  *                 |                           |
| mayo1                     |                          |                  *                 |                  *                 |                           |
| mayo2                     |                          |                  *                 |                  *                 |                           |
| mayo3                     |                          |                  *                 |                  *                 |                           |
| mayo5                     |                          |                  *                 |                  *                 |                           |
| p256_mayo1                |             *            |                  *                 |                  *                 |                           |
| p256_mayo2                |             *            |                  *                 |                  *                 |                           |
| p384_mayo3                |             *            |                  *                 |                  *                 |                           |
| p521_mayo5                |             *            |                  *                 |                  *                 |                           |
| CROSSrsdp128balanced      |                          |                  *                 |                  *                 |                           |
| CROSSrsdp128fast          |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp128small         |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp192balanced      |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp192fast          |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp192small         |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp256small         |                          |                                    |                  *                 |             *             |
| CROSSrsdpg128balanced     |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg128fast         |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg128small        |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg192balanced     |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg192fast         |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg192small        |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg256balanced     |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg256fast         |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg256small        |                          |                  *                 |                  *                 |             *             |
| OV_Is                     |                          |                                    |                  *                 |             *             |
| OV_Ip                     |                          |                                    |                  *                 |             *             |
| OV_III                    |                          |                                    |                  *                 |             *             |
| OV_V                      |                          |                                    |                  *                 |             *             |
| OV_Is_pkc                 |                          |                                    |                  *                 |             *             |
| OV_Ip_pkc                 |                          |                  *                 |                  *                 |                           |
| OV_III_pkc                |                          |                                    |                  *                 |             *             |
| OV_V_pkc                  |                          |                                    |                  *                 |             *             |
| OV_Is_pkc_skc             |                          |                                    |                  *                 |             *             |
| OV_Ip_pkc_skc             |                          |                  *                 |                  *                 |                           |
| OV_III_pkc_skc            |                          |                                    |                  *                 |             *             |
| OV_V_pkc_skc              |                          |                                    |                  *                 |             *             |
| p256_OV_Is                |             *            |                                    |                  *                 |             *             |
| p256_OV_Ip                |             *            |                                    |                  *                 |             *             |
| p384_OV_III               |             *            |                                    |                  *                 |             *             |
| p521_OV_V                 |             *            |                                    |                  *                 |             *             |
| p256_OV_Is_pkc            |             *            |                                    |                  *                 |             *             |
| p256_OV_Ip_pkc            |             *            |                  *                 |                  *                 |                           |
| p384_OV_III_pkc           |             *            |                                    |                  *                 |             *             |
| p521_OV_V_pkc             |             *            |                                    |                  *                 |             *             |
| p256_OV_Is_pkc_skc        |             *            |                                    |                  *                 |             *             |
| p256_OV_Ip_pkc_skc        |             *            |                  *                 |                  *                 |                           |
| p384_OV_III_pkc_skc       |             *            |                                    |                  *                 |             *             |
| p521_OV_V_pkc_skc         |             *            |                                    |                  *                 |             *             |
| snova2454                 |                          |                  *                 |                  *                 |                           |
| snova2454shake            |                          |                                    |                  *                 |             *             |
| snova2454esk              |                          |                  *                 |                  *                 |                           |
| snova2454shakeesk         |                          |                                    |                  *                 |             *             |
| snova37172                |                          |                  *                 |                  *                 |                           |
| snova2583                 |                          |                                    |                  *                 |             *             |
| snova56252                |                          |                                    |                  *                 |             *             |
| snova49113                |                          |                                    |                  *                 |             *             |
| snova3784                 |                          |                                    |                  *                 |             *             |
| snova2455                 |                          |                  *                 |                  *                 |                           |
| snova60104                |                          |                                    |                  *                 |             *             |
| snova2965                 |                          |                  *                 |                  *                 |                           |
| p256_snova2454            |             *            |                  *                 |                  *                 |                           |
| p256_snova2454shake       |             *            |                                    |                  *                 |             *             |
| p256_snova2454esk         |             *            |                  *                 |                  *                 |                           |
| p256_snova2454shakeesk    |             *            |                                    |                  *                 |             *             |
| p256_snova37172           |             *            |                  *                 |                  *                 |                           |
| p256_snova2583            |             *            |                                    |                  *                 |             *             |
| p384_snova56252           |             *            |                                    |                  *                 |             *             |
| p384_snova49113           |             *            |                                    |                  *                 |             *             |
| p384_snova3784            |             *            |                                    |                  *                 |             *             |
| p384_snova2455            |             *            |                  *                 |                  *                 |                           |
| p521_snova60104           |             *            |                                    |                  *                 |             *             |
| p521_snova2965            |             *            |                  *                 |                  *                 |                           |
| mqom2cat1gf16fastr5       |                          |                  *                 |                  *                 |                           |
| mqom2cat1gf16fastr3       |                          |                  *                 |                  *                 |             *             |
| mqom2cat1gf16shortr5      |                          |                  *                 |                  *                 |             *             |
| mqom2cat1gf16shortr3      |                          |                  *                 |                  *                 |             *             |
| mqom2cat3gf16fastr5       |                          |                  *                 |                  *                 |                           |
| mqom2cat3gf16fastr3       |                          |                  *                 |                  *                 |             *             |
| mqom2cat3gf16shortr5      |                          |                  *                 |                  *                 |             *             |
| mqom2cat3gf16shortr3      |                          |                  *                 |                  *                 |             *             |
| mqom2cat5gf16fastr5       |                          |                  *                 |                  *                 |                           |
| mqom2cat5gf16fastr3       |                          |                  *                 |                  *                 |             *             |
| mqom2cat5gf16shortr5      |                          |                  *                 |                  *                 |             *             |
| mqom2cat5gf16shortr3      |                          |                  *                 |                  *                 |             *             |
| p256_mqom2cat1gf16fastr5  |             *            |                  *                 |                  *                 |                           |
| p256_mqom2cat1gf16fastr3  |             *            |                  *                 |                  *                 |             *             |
| p256_mqom2cat1gf16shortr5 |             *            |                  *                 |                  *                 |             *             |
| p256_mqom2cat1gf16shortr3 |             *            |                  *                 |                  *                 |             *             |
| p384_mqom2cat3gf16fastr5  |             *            |                  *                 |                  *                 |                           |
| p384_mqom2cat3gf16fastr3  |             *            |                  *                 |                  *                 |             *             |
| p384_mqom2cat3gf16shortr5 |             *            |                  *                 |                  *                 |             *             |
| p384_mqom2cat3gf16shortr3 |             *            |                  *                 |                  *                 |             *             |
| p521_mqom2cat5gf16fastr5  |             *            |                  *                 |                  *                 |                           |
| p521_mqom2cat5gf16fastr3  |             *            |                  *                 |                  *                 |             *             |
| p521_mqom2cat5gf16shortr5 |             *            |                  *                 |                  *                 |             *             |
| p521_mqom2cat5gf16shortr3 |             *            |                  *                 |                  *                 |             *             |

## External Documentation
For additional reference, the upstream dependency documentation corresponding to the pinned versions used by PQC-LEO can be found below:

- [Liboqs v0.16.0 – Supported Algorithms](https://github.com/open-quantum-safe/liboqs/blob/5a1a854b0dc9f2141bdc771c555ee60c37950183/ALGORITHMS.md)
- [OpenSSL 3.6.1 – PQC Listed in Documenation Overviews](https://docs.openssl.org/3.6/man7/)
- [OQS-Provider v0.11.0+ – Supported Algorithms](https://github.com/open-quantum-safe/oqs-provider/blob/1670a8a91bbca997d33e6b6851309d6241cc224c/ALGORITHMS.md)