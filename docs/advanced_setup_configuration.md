# Advanced Setup Configurations
This document outlines additional configuration options when running the `setup.sh` script. The main setup supports the following advanced configurations:

- Use the latest versions of the OQS dependency libraries
- Manually adjusting OpenSSL's `s_speed` tool hardcoded limits
- Enabling HQC KEM algorithms in Liboqs and OQS-Provider

## Using the Latest Versions of the OQS Libraries
By default, the setup process uses specific pinned commits of the OQS libraries that correspond to the last tested repository state verified for compatibility with this project's automation tools. However, users may opt to use the latest upstream versions of the dependencies by passing the following flag to the setup script:

```
./setup.sh --latest-dependency-versions
```

This option may provide access to the most recent algorithm updates and bug fixes, but it may also introduce breaking changes due to upstream modifications. The setup script will display a warning and require explicit confirmation before proceeding with the latest versions.

For more information on the specific versions used by default, see the [Dependency Libraries](./developer_information/dependency_libraries.md) documentation.

## Adjusting OpenSSL speed Tool Hardcoded Limits
When using either the `full` or `TLS-only` install modes, an optional prompt will appear that allows enabling all digital signature algorithms that are disabled by default in the OQS-Provider library.

By default, the main setup script will attempt to detect and patch these values automatically in the `s_speed` tool's source code to increase the hard coded limits if needed. However, if you wish to manually set a custom value (or if auto-patching fails), you can use the following flag:

```
./setup.sh --set-speed-new-value=[integer]
```

Replace [integer] with the desired value. The setup script will then patch the `speed.c` source file to set both `MAX_KEM_NUM` and `MAX_SIG_NUM` to this value before compiling OpenSSL.

For further details on this issue and the plans to address the problem in the future, please refer to this [git issue](https://github.com/crt26/pqc-evaluation-tools/issues/25) on the repositories page.

## Enabling HQC KEM Algorithms in Liboqs and OQS-Provider
Recent versions of both Liboqs and OQS-Provider disable HQC KEM algorithms by default, due to their current implementations not conforming to the latest specification, which includes important security fixes. This project provides optional setup flags to re-enable HQC **strictly for benchmarking purposes**, with full user awareness and consent. When enabling HQC, the setup script will display a security warning and require confirmation before continuing. If declined, HQC remains disabled.

To enable HQC KEM algorithms, the following flags can be passed to the `setup.sh` script:

| **Flag**                   | **Description**                                                                                                 |
|----------------------------|-----------------------------------------------------------------------------------------------------------------|
| `--enable-liboqs-hqc-algs` | Enables HQC algorithms in Liboqs only.                                                                          |
| `--enable-oqs-hqc-algs`    | Enables HQC algorithms in OQS-Provider only. Liboqs HQC must also be enabled. The script will prompt if needed. |
| `--enable-all-hqc-algs`    | Enables HQC algorithms in both Liboqs and OQS-Provider. Overrides the other two flags if present.               |


Example usage include:
```
./setup.sh --enable-all-hqc-algs
```

If HQC is enabled (depending on which enable type is selected):

- Liboqs is built with -DOQS_ENABLE_KEM_HQC=ON.
- OQS-Provider's generate.yml is updated to enable HQC 
- A .hqc_enabled.flag is created in the tmp/ directory to inform other tools
- The get_algorithms.py utility includes HQC in algorithm lists

**Important:** If HQC is enabled, the resulting OQS builds should only be used within this project's benchmarking tools. It must not be used for anything other than its intended purpose.

For additional context, please see:
- [Liboqs Pull Request #2122](https://github.com/open-quantum-safe/liboqs/pull/2122)
- [Liboqs Issue #2118](https://github.com/open-quantum-safe/liboqs/issues/2118)
- [PQC-Evaluation-Tools Issue #46](https://github.com/crt26/pqc-evaluation-tools/issues/46)
- [PQC-Evaluation-Tools Issue #60](https://github.com/crt26/pqc-evaluation-tools/issues/60)
- [Disclaimer Document](../DISCLAIMER.md)