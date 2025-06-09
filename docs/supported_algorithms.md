# Supported PQC Algorithms <!-- omit from toc -->

## Support Overview <!-- omit from toc -->
This document outlines the Key Encapsulation Mechanisms (KEMs) and digital signature algorithms supported by this project, based on its upstream cryptographic dependencies: Liboqs, OQS-Provider, and OpenSSL. While the PQC-Evaluation-Tools project integrates nearly all algorithms from these libraries, there are a few exceptions.

It contains comprehensive lists of all supported PQC algorithms, along with any exclusions and the rationale behind them. For additional reference, the upstream dependency documentation can be found here:

- [Liboqs Supported Algorithms](https://github.com/open-quantum-safe/liboqs?tab=readme-ov-file#supported-algorithms)
- [OpenSSL Supported PQC Algorithms](https://github.com/openssl/openssl/releases/tag/openssl-3.5.0)
- [OQS-Provider Supported Algorithms](https://github.com/open-quantum-safe/oqs-provider/blob/main/ALGORITHMS.md)

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

## Dependency Usage by Testing Category
Different testing categories within this project rely on distinct combinations of upstream cryptographic dependencies. The table below summarises which libraries are used in each context:

| **Testing Category**              | **Dependencies Used**       |
|-----------------------------------|-----------------------------|
| Computational Performance Testing | Liboqs                      |
| TLS Handshake Testing             | OpenSSL 3.5.0, OQS-Provider |
| OpenSSL speed Benchmarking        | OpenSSL 3.5.0, OQS-Provider |

Although the OQS-Provider depends on Liboqs for algorithm implementations, it exposes a different set of algorithms. As such, its supported algorithms are documented separately in this guide.

## Liboqs Algorithms

### Algorithm Support Summary
The PQC-Evaluation-Tools project supports all key encapsulation mechanisms (KEMs) and digital signature algorithms provided by Liboqs, with three notable exceptions:

- **HQC** -  its variants are disabled by default in both Liboqs and the OQS-Provider due to their current implementations not conforming to the latest specification, which includes important security fixes. As a result, HQC algorithms are excluded from all performance benchmarking unless explicitly enabled by the user using dedicated flags during the setup process.

- **Falcon** digital signature variants are not compatible with **memory profiling on ARM systems** due to issues between the scheme’s structure and the Valgrind Massif tool. This does not affect general functional testing or result parsing, which remain fully supported across all platforms.

- **Stateful signature schemes (XMSS and LMS)** are currently excluded from this project. Although Liboqs supports them, they are disabled by default and require hazardous experimental build flags to enable key generation and signing. These schemes are not part of the NIST standardisation process, and Liboqs explicitly warns that support may be removed in future releases if misused. Their inclusion within this project may be reconsidered in a future release if justified.

These exceptions are reflected in the tables below. If users wish to enable HQC despite the associated risks, detailed instructions are provided in the advanced setup guide.

For further context and guidance:

- See the [Advanced Setup Configuration Guide](./advanced_setup_configuration.md) for instructions on enabling HQC.
- Refer to the [Disclaimer Document](../DISCLAIMER.md) for security warnings and usage guidance.

### Supported KEM Algorithms

| **Algorithm Name**        | **NIST Security Level** | **Requires Enabling (*)** |
|---------------------------|:-----------------------:|:-------------------------:|
| BIKE-L1                   |            1            |                           |
| BIKE-L3                   |            3            |                           |
| BIKE-L5                   |            5            |                           |
| Classic-McEliece-348864   |            1            |                           |
| Classic-McEliece-348864f  |            1            |                           |
| Classic-McEliece-460896   |            3            |                           |
| Classic-McEliece-460896f  |            3            |                           |
| Classic-McEliece-6688128  |            5            |                           |
| Classic-McEliece-6688128f |            5            |                           |
| Classic-McEliece-6960119  |            5            |                           |
| Classic-McEliece-6960119f |            5            |                           |
| Classic-McEliece-8192128  |            5            |                           |
| Classic-McEliece-8192128f |            5            |                           |
| Kyber512                  |            1            |                           |
| Kyber768                  |            3            |                           |
| Kyber1024                 |            5            |                           |
| ML-KEM-512                |            1            |                           |
| ML-KEM-768                |            3            |                           |
| ML-KEM-1024               |            5            |                           |
| sntrup761                 |            2            |                           |
| FrodoKEM-640-AES          |            1            |                           |
| FrodoKEM-640-SHAKE        |            1            |                           |
| FrodoKEM-976-AES          |            3            |                           |
| FrodoKEM-976-SHAKE        |            3            |                           |
| FrodoKEM-1344-AES         |            5            |                           |
| FrodoKEM-1344-SHAKE       |            5            |                           |
| HQC-128                   |            1            |             *             |
| HQC-192                   |            3            |             *             |
| HQC-256                   |            5            |             *             |

### Supported Digital Signature Algorithms

| **Algorithm Name**         | **NIST Security Level** | **Requires Enabling (*)** |
|----------------------------|:-----------------------:|:-------------------------:|
| Dilithium2                 |            2            |                           |
| Dilithium3                 |            3            |                           |
| Dilithium5                 |            5            |                           |
| ML-DSA-44                  |            2            |                           |
| ML-DSA-65                  |            3            |                           |
| ML-DSA-87                  |            5            |                           |
| Falcon-512                 |            1            |                           |
| Falcon-1024                |            5            |                           |
| Falcon-padded-512          |            1            |                           |
| Falcon-padded-1024         |            5            |                           |
| SPHINCS+-SHA2-128f-simple  |            1            |                           |
| SPHINCS+-SHA2-128s-simple  |            1            |                           |
| SPHINCS+-SHA2-192f-simple  |            3            |                           |
| SPHINCS+-SHA2-192s-simple  |            3            |                           |
| SPHINCS+-SHA2-256f-simple  |            5            |                           |
| SPHINCS+-SHA2-256s-simple  |            5            |                           |
| SPHINCS+-SHAKE-128f-simple |            1            |                           |
| SPHINCS+-SHAKE-128s-simple |            1            |                           |
| SPHINCS+-SHAKE-192f-simple |            3            |                           |
| SPHINCS+-SHAKE-192s-simple |            3            |                           |
| SPHINCS+-SHAKE-256f-simple |            5            |                           |
| SPHINCS+-SHAKE-256s-simple |            5            |                           |
| MAYO-1                     |            1            |                           |
| MAYO-2                     |            1            |                           |
| MAYO-3                     |            3            |                           |
| MAYO-5                     |            5            |                           |
| cross-rsdp-128-balanced    |            1            |                           |
| cross-rsdp-128-fast        |            1            |                           |
| cross-rsdp-128-small       |            1            |                           |
| cross-rsdp-192-balanced    |            3            |                           |
| cross-rsdp-192-fast        |            3            |                           |
| cross-rsdp-192-small       |            3            |                           |
| cross-rsdp-256-balanced    |            5            |                           |
| cross-rsdp-256-fast        |            5            |                           |
| cross-rsdp-256-small       |            5            |                           |
| cross-rsdpg-128-balanced   |            1            |                           |
| cross-rsdpg-128-fast       |            1            |                           |
| cross-rsdpg-128-small      |            1            |                           |
| cross-rsdpg-192-balanced   |            3            |                           |
| cross-rsdpg-192-fast       |            3            |                           |
| cross-rsdpg-192-small      |            3            |                           |
| cross-rsdpg-256-balanced   |            5            |                           |
| cross-rsdpg-256-fast       |            5            |                           |
| cross-rsdpg-256-small      |            5            |                           |
| OV-Is                      |            1            |                           |
| OV-Ip                      |            1            |                           |
| OV-III                     |            3            |                           |
| OV-V                       |            5            |                           |
| OV-Is-pkc                  |            1            |                           |
| OV-Ip-pkc                  |            1            |                           |
| OV-III-pkc                 |            3            |                           |
| OV-V-pkc                   |            5            |                           |
| OV-Is-pkc-skc              |            1            |                           |
| OV-Ip-pkc-skc              |            1            |                           |
| OV-III-pkc-skc             |            3            |                           |
| OV-V-pkc-skc               |            5            |                           |
| SNOVA_24_5_4               |            1            |                           |
| SNOVA_24_5_4_SHAKE         |            1            |                           |
| SNOVA_24_5_4_esk           |            1            |                           |
| SNOVA_24_5_4_SHAKE_esk     |            1            |                           |
| SNOVA_37_17_2              |            1            |                           |
| SNOVA_25_8_3               |            1            |                           |
| SNOVA_56_25_2              |            3            |                           |
| SNOVA_49_11_3              |            3            |                           |
| SNOVA_37_8_4               |            3            |                           |
| SNOVA_24_5_5               |            3            |                           |
| SNOVA_60_10_4              |            5            |                           |
| SNOVA_29_6_5               |            5            |                           |

## OpenSSL Algorithms

### Algorithm Support Summary
OpenSSL 3.5.0 introduces native support for the NIST-standardised PQC algorithms **ML-KEM**, **ML-DSA**, and **SLH-DSA**. This project integrates these algorithms for TLS benchmarking where possible. However, some limitations affect their usage in performance testing and handshake scenarios:

#### Known Limitations
- **ML-DSA** and **SLH-DSA** are currently not supported by the OpenSSL `speed` utility, making them unavailable for cryptographic performance benchmarking.

- **SLH-DSA** while supported at the provider level (e.g., for certificate generation), has not yet been integrated into OpenSSL's TLS stack (`s_client`, `s_server`, `speed`). Its inclusion in TLS 1.3 is under consideration via this [IETF draft](https://datatracker.ietf.org/doc/html/draft-reddy-tls-slhdsa-01). Until then, SPHINCS+ from the OQS-Provider will be used as a placeholder for stateless hash-based signatures in TLS tests.
  
- The **X448MLKEM1024** Hybrid-PQC KEM is implemented and supported by OpenSSL's `speed` tool, but not registered as a TLS group. It is excluded from handshake testing, though it remains available for TLS speed testing within this project.

#### Classical Algorithm Benchmarks
To provide performance baselines for comparison, classical algorithms are also included in TLS benchmarking:

- RSA-2048, RSA-3072, RSA-4096
- prime256v1, secp384r1, secp521r1

These schemes help assess the overhead and feasibility of PQC adoption in real-world contexts.

### Supported KEM Algorithms

| **Algorithm Name** | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** |
|--------------------|:------------------------:|:----------------------------------:|:----------------------------------:|
| MLKEM512           |                          |                  *                 |                  *                 |
| MLKEM768           |                          |                  *                 |                                    |
| MLKEM1024          |                          |                  *                 |                  *                 |
| X25519MLKEM768     |             *            |                  *                 |                  *                 |
| X448MLKEM1024      |             *            |                                    |                  *                 |
| SecP256r1MLKEM768  |             *            |                  *                 |                  *                 |
| SecP384r1MLKEM1024 |             *            |                  *                 |                  *                 |

### Supported Digital Signature Algorithms

| **Algorithm Name** | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** |
|--------------------|:------------------------:|:----------------------------------:|:----------------------------------:|
| MLDSA44            |                          |                  *                 |                                    |
| MLDSA65            |                          |                  *                 |                                    |
| MLDSA87            |                          |                  *                 |                                    |

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

#### Known General Limitations
**HQC** and its variants are disabled by default in both Liboqs and the OQS-Provider due to their current implementations not conforming to the latest specification, which includes important security fixes. As a result, HQC algorithms are excluded from all performance benchmarking unless explicitly enabled by the user using dedicated flags during the setup process.

#### Known TLS Handshake Testing Limitations
Certain variations of the supported digital signature schemes are excluded from TLS handshake testing due to non-compliance with [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446), which defines the specifications of the TLS 1.3 protocol. These include:

- **UOV Scheme Variations**
- **SNOVA Scheme Variations**
- **CROSSrsdp256small**

These schemes remain available for use in the TLS speed tests that the PQC-Evaluation-Tools provides using the OpenSSL `speed` tool. 

Whilst a significant number of these scheme variations can not be used in TLS Handshake testing, there are the following exceptions:

| **Scheme** | **Variations Supported for TLS Handshake Testing**                                                                                            |
|------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| UOV         | OV_Ip_pkc, p256_OV_Ip_pkc, OV_Ip_pkc_skc, p256_OV_Ip_pkc_skc                                                                                  |
| SNOVA      | snova2454, p256_snova2454, snova2454esk, p256_snova2454esk, snova37172, p256_snova37172, snova2455, p384_snova2455, snova2965, p521_snova2965 |
| CROSSrsdp  | CROSSrsdp256small                                                                                                                             |

#### OpenSSL 3.5.0 Compatibility
With the introduction of native PQC support in OpenSSL 3.5.0, the OQS-Provider automatically disables its implementations of overlapping algorithms (e.g., ML-KEM, ML-DSA, SLH-DSA) to prevent provider conflicts during initialisation. For more information, see the relevant OQS-Provider documentation below.

#### Additional Information
For further details on algorithm support, compatibility, HQC implementation issues, or enabling algorithms disabled by default, see:

- [OQS-Provider Notice](https://github.com/open-quantum-safe/oqs-provider?tab=readme-ov-file#35-and-greater)
- [Advanced Setup Configuration Guide](./advanced_setup_configuration.md)
- [Disclaimer Document](../DISCLAIMER.md)

### Supported KEM Algorithms

| **Algorithm Name**   | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** | **Requires Enabling (*)** |
|----------------------|:------------------------:|:----------------------------------:|:----------------------------------:|:-------------------------:|
| frodo640aes          |                          |                  *                 |                  *                 |                           |
| frodo640shake        |                          |                  *                 |                  *                 |                           |
| frodo976aes          |                          |                  *                 |                  *                 |                           |
| frodo976shake        |                          |                  *                 |                  *                 |                           |
| frodo1344aes         |                          |                  *                 |                  *                 |                           |
| frodo1344shake       |                          |                  *                 |                  *                 |                           |
| p256_frodo640aes     |             *            |                  *                 |                  *                 |                           |
| x25519_frodo640aes   |             *            |                  *                 |                  *                 |                           |
| p256_frodo640shake   |             *            |                  *                 |                  *                 |                           |
| x25519_frodo640shake |             *            |                  *                 |                  *                 |                           |
| p384_frodo976aes     |             *            |                  *                 |                  *                 |                           |
| x448_frodo976aes     |             *            |                  *                 |                  *                 |                           |
| p384_frodo976shake   |             *            |                  *                 |                  *                 |                           |
| x448_frodo976shake   |             *            |                  *                 |                  *                 |                           |
| p521_frodo1344aes    |             *            |                  *                 |                  *                 |                           |
| p521_frodo1344shake  |             *            |                  *                 |                  *                 |                           |
| bikel1               |                          |                  *                 |                  *                 |                           |
| bikel3               |                          |                  *                 |                  *                 |                           |
| bikel5               |                          |                  *                 |                  *                 |                           |
| p256_bikel1          |             *            |                  *                 |                  *                 |                           |
| x25519_bikel1        |             *            |                  *                 |                  *                 |                           |
| p384_bikel3          |             *            |                  *                 |                  *                 |                           |
| x448_bikel3          |             *            |                  *                 |                  *                 |                           |
| p521_bikel5          |             *            |                  *                 |                  *                 |                           |
| p256_mlkem512        |             *            |                  *                 |                  *                 |                           |
| x25519_mlkem512      |             *            |                  *                 |                  *                 |                           |
| p384_mlkem768        |             *            |                  *                 |                  *                 |                           |
| x448_mlkem768        |             *            |                  *                 |                  *                 |                           |
| p521_mlkem1024       |             *            |                  *                 |                  *                 |                           |
| hqc128               |                          |                  *                 |                  *                 |             *             |
| hqc192               |                          |                  *                 |                  *                 |             *             |
| hqc256               |                          |                  *                 |                  *                 |             *             |


### Supported Digital Signature Algorithms

| **Algorithm Name**             | **Hybrid Algorithm (*)** | **TLS Handshake Test Support (*)** | **OpenSSL Speed Test Support (*)** | **Requires Enabling (*)** |
|--------------------------------|:------------------------:|:----------------------------------:|:----------------------------------:|:-------------------------:|
| falcon512                      |                          |                  *                 |                  *                 |                           |
| falconpadded512                |                          |                  *                 |                  *                 |                           |
| falcon1024                     |                          |                  *                 |                  *                 |                           |
| falconpadded1024               |                          |                  *                 |                  *                 |                           |
| p256_falcon512                 |             *            |                  *                 |                  *                 |                           |
| rsa3072_falcon512              |             *            |                  *                 |                  *                 |                           |
| p256_falconpadded512           |             *            |                  *                 |                  *                 |                           |
| rsa3072_falconpadded512        |             *            |                  *                 |                  *                 |                           |
| p521_falcon1024                |             *            |                  *                 |                  *                 |                           |
| p521_falconpadded1024          |             *            |                  *                 |                  *                 |                           |
| sphincssha2128fsimple          |                          |                  *                 |                  *                 |                           |
| sphincssha2128ssimple          |                          |                  *                 |                  *                 |                           |
| sphincssha2192fsimple          |                          |                  *                 |                  *                 |                           |
| sphincssha2192ssimple          |                          |                  *                 |                  *                 |             *             |
| sphincssha2256fsimple          |                          |                  *                 |                  *                 |             *             |
| sphincssha2256ssimple          |                          |                  *                 |                  *                 |             *             |
| sphincsshake128fsimple         |                          |                  *                 |                  *                 |                           |
| sphincsshake128ssimple         |                          |                  *                 |                  *                 |             *             |
| sphincsshake192fsimple         |                          |                  *                 |                  *                 |             *             |
| sphincsshake192ssimple         |                          |                  *                 |                  *                 |             *             |
| sphincsshake256fsimple         |                          |                  *                 |                  *                 |             *             |
| sphincsshake256ssimple         |                          |                  *                 |                  *                 |             *             |
| p256_sphincssha2128fsimple     |             *            |                  *                 |                  *                 |                           |
| rsa3072_sphincssha2128fsimple  |             *            |                  *                 |                  *                 |                           |
| p256_sphincssha2128ssimple     |             *            |                  *                 |                  *                 |                           |
| rsa3072_sphincssha2128ssimple  |             *            |                  *                 |                  *                 |                           |
| p384_sphincssha2192fsimple     |             *            |                  *                 |                  *                 |                           |
| p384_sphincssha2192ssimple     |             *            |                  *                 |                  *                 |                           |
| p521_sphincssha2256fsimple     |             *            |                  *                 |                  *                 |             *             |
| p521_sphincssha2256ssimple     |             *            |                  *                 |                  *                 |             *             |
| p256_sphincsshake128fsimple    |             *            |                  *                 |                  *                 |                           |
| rsa3072_sphincsshake128fsimple |             *            |                  *                 |                  *                 |                           |
| p256_sphincsshake128ssimple    |             *            |                  *                 |                  *                 |             *             |
| rsa3072_sphincsshake128ssimple |             *            |                  *                 |                  *                 |             *             |
| p384_sphincsshake192fsimple    |             *            |                  *                 |                  *                 |             *             |
| p384_sphincsshake192ssimple    |             *            |                  *                 |                  *                 |             *             |
| p521_sphincsshake256fsimple    |             *            |                  *                 |                  *                 |             *             |
| p521_sphincsshake256ssimple    |             *            |                  *                 |                  *                 |             *             |
| mayo1                          |                          |                  *                 |                  *                 |                           |
| mayo2                          |                          |                  *                 |                  *                 |                           |
| mayo3                          |                          |                  *                 |                  *                 |                           |
| mayo5                          |                          |                  *                 |                  *                 |                           |
| p256_mayo1                     |             *            |                  *                 |                  *                 |                           |
| p256_mayo2                     |             *            |                  *                 |                  *                 |                           |
| p384_mayo3                     |             *            |                  *                 |                  *                 |                           |
| p521_mayo5                     |             *            |                  *                 |                  *                 |                           |
| CROSSrsdp128balanced           |                          |                  *                 |                  *                 |                           |
| CROSSrsdp128fast               |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp128small              |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp192balanced           |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp192fast               |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp192small              |                          |                  *                 |                  *                 |             *             |
| CROSSrsdp256small              |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg128balanced          |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg128fast              |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg128small             |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg192balanced          |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg192fast              |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg192small             |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg256balanced          |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg256fast              |                          |                  *                 |                  *                 |             *             |
| CROSSrsdpg256small             |                          |                                    |                  *                 |             *             |
| OV_Is                          |                          |                                    |                  *                 |             *             |
| OV_Ip                          |                          |                                    |                  *                 |             *             |
| OV_III                         |                          |                                    |                  *                 |             *             |
| OV_V                           |                          |                                    |                  *                 |             *             |
| OV_Is_pkc                      |                          |                                    |                  *                 |                           |
| OV_Ip_pkc                      |                          |                  *                 |                  *                 |                           |
| OV_III_pkc                     |                          |                                    |                  *                 |             *             |
| OV_V_pkc                       |                          |                                    |                  *                 |             *             |
| OV_Is_pkc_skc                  |                          |                                    |                  *                 |                           |
| OV_Ip_pkc_skc                  |                          |                  *                 |                  *                 |                           |
| OV_III_pkc_skc                 |                          |                                    |                  *                 |             *             |
| OV_V_pkc_skc                   |                          |                                    |                  *                 |             *             |
| p256_OV_Is                     |             *            |                                    |                  *                 |             *             |
| p256_OV_Ip                     |             *            |                                    |                  *                 |             *             |
| p384_OV_III                    |             *            |                                    |                  *                 |             *             |
| p521_OV_V                      |             *            |                                    |                  *                 |             *             |
| p256_OV_Is_pkc                 |             *            |                                    |                  *                 |                           |
| p256_OV_Ip_pkc                 |             *            |                  *                 |                  *                 |                           |
| p384_OV_III_pkc                |             *            |                                    |                  *                 |             *             |
| p521_OV_V_pkc                  |             *            |                                    |                  *                 |             *             |
| p256_OV_Is_pkc_skc             |             *            |                                    |                  *                 |                           |
| p256_OV_Ip_pkc_skc             |             *            |                  *                 |                  *                 |                           |
| p384_OV_III_pkc_skc            |             *            |                                    |                  *                 |             *             |
| p521_OV_V_pkc_skc              |             *            |                                    |                  *                 |             *             |
| p256_mldsa44                   |             *            |                  *                 |                  *                 |             *             |
| rsa3072_mldsa44                |             *            |                  *                 |                  *                 |             *             |
| p384_mldsa65                   |             *            |                  *                 |                  *                 |             *             |
| p521_mldsa87                   |             *            |                  *                 |                  *                 |             *             |
| snova2454                      |                          |                  *                 |                  *                 |                           |
| snova2454shake                 |                          |                                    |                  *                 |             *             |
| snova2454esk                   |                          |                  *                 |                  *                 |                           |
| snova2454shakeesk              |                          |                                    |                  *                 |             *             |
| snova37172                     |                          |                  *                 |                  *                 |                           |
| snova2583                      |                          |                                    |                  *                 |             *             |
| snova56252                     |                          |                                    |                  *                 |             *             |
| snova49113                     |                          |                                    |                  *                 |             *             |
| snova3784                      |                          |                                    |                  *                 |             *             |
| snova2455                      |                          |                  *                 |                  *                 |                           |
| snova60104                     |                          |                                    |                  *                 |             *             |
| snova2965                      |                          |                  *                 |                  *                 |                           |
| p256_snova2454                 |             *            |                  *                 |                  *                 |                           |
| p256_snova2454shake            |             *            |                                    |                  *                 |             *             |
| p256_snova2454esk              |             *            |                  *                 |                  *                 |                           |
| p256_snova2454shakeesk         |             *            |                                    |                  *                 |             *             |
| p256_snova37172                |             *            |                  *                 |                  *                 |                           |
| p256_snova2583                 |             *            |                                    |                  *                 |             *             |
| p384_snova56252                |             *            |                                    |                  *                 |             *             |
| p384_snova49113                |             *            |                                    |                  *                 |             *             |
| p384_snova3784                 |             *            |                                    |                  *                 |             *             |
| p384_snova2455                 |             *            |                  *                 |                  *                 |                           |
| p521_snova60104                |             *            |                                    |                  *                 |             *             |
| p521_snova2965                 |             *            |                  *                 |                  *                 |                           |

