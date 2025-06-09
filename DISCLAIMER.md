# Project Disclaimer

## General Disclaimer
This project is intended solely for research and benchmarking purposes. The tools and scripts provided in this repository are designed to benchmark the computational and TLS-level performance of Post-Quantum Cryptography (PQC) algorithms in controlled environments. They are not intended for production use or security-critical applications.

The maintainers of this project assume no liability for any consequences resulting from the use or misuse of this repository or its components.

Users are expected to understand the implications of enabling, modifying, or extending any parts of the framework, especially when integrating with cryptographic libraries and systems.

## Third-Party Licence Compliance
This project complies with the licensing terms of all third-party software and libraries it utilises. All dependencies are downloaded and built locally during the setup process; however, this repository does include modified versions of specific source files from third-party projects where necessary.

In particular:

- Modified versions of the `test_kem_mem.c` and `test_sig_mem.c` files from the **Liboqs** project are distributed in this repository. These files have been adapted to support detailed memory benchmarking with reduced terminal output. The original MIT Licence is retained at the top of each modified file, and these modifications remain subject to that licence.

All other third-party dependencies are incorporated dynamically during setup:

- **Liboqs** and **OQS-Provider** are modified and built locally under the MIT Licence.
- **OpenSSL** is dynamically patched and built during setup under the Apache Licence 2.0.
- **pqax** is used without modification under the Creative Commons Zero v1.0 Universal (CC0) Licence.

Users are responsible for ensuring compliance with all relevant third-party licences, particularly if redistributing binaries or integrating this project into larger systems.

## HQC Algorithm Inclusion Disclaimer
The HQC KEM algorithms are disabled by default in both Liboqs and OQS-Provider due to the current implementation not conforming to the latest reference specification. This includes fixes for a previously identified security flaw that breaks IND-CCA2 guarantees under specific attack models.

As a result, the PQC Evaluation Tools framework provides an optional mechanism to enable HQC **solely for benchmarking purposes**. Users who choose to enable HQC will be warned about the associated risks and must explicitly acknowledge and confirm their decision to proceed. Please refer to the [Advanced Setup Configuration](docs/advanced_setup_configuration.md) for details on enabling HQC.

Enabling HQC is done at the user's discretion, and users will be required to explicitly acknowledge the risks and confirm that they wish to proceed. The project maintainers make no guarantees about the correctness, security, or compliance of HQC as currently implemented in the OQS libraries. Enabling HQC is done entirely at your own risk, and this project assumes no responsibility for any issues that may arise from its use.

If HQC is enabled:

- It must only be used within the provided testing tools.
- It must not be used in production systems or real-world cryptographic deployments.

For more information, see:
- [Liboqs Pull Request #2122](https://github.com/open-quantum-safe/liboqs/pull/2122)
- [Liboqs Issue #2118](https://github.com/open-quantum-safe/liboqs/issues/2118)
- [PQC-Evaluation-Tools Issue #46](https://github.com/crt26/pqc-evaluation-tools/issues/46)
- [PQC-Evaluation-Tools Issue #60](https://github.com/crt26/pqc-evaluation-tools/issues/60)