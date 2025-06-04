# Advanced Setup Configurations
This document outlines additional configuration options when running the `setup.sh` script. The main setup supports the following advanced configurations when called:

- Use the latest versions of the OQS dependency libraries
- Manually Adjusting OpenSSL's `s_speed` Tool Hardcoded Limits
- Enabling HQC KEM Algorithms in Liboqs

## Using the Latest Versions of the OQS Libraries
By default, the setup process uses the **last tested versions** of the OQS libraries to ensure compatibility with this project's automation tools. However, users may opt to use the latest upstream versions of the dependencies by passing the following flag to the setup script:

```
./setup.sh --latest-dependency-versions
```

This option may provide access to the most recent algorithm updates and bug fixes, but it may also introduce breaking changes due to upstream modifications. The setup script will display a warning and require explicit confirmation before proceeding with the latest versions.

For more information on the specific versions used by default, see the [Dependency Libraries](./developer_information/dependency_libraries.md) documentation.

## Adjusting OpenSSL speed Tool Hardcoded Limits
When the setup script is run using the `Full Install` or `TLS Testing Libraries Only` modes, an optional prompt allows enabling all digital signature algorithms disabled by default in the OQS-Provider library. If this option is selected, the total number of registered signatures and KEM algorithms may exceed OpenSSL's internal limits. This causes the OpenSSL `s_speed` benchmarking tool to fail due to hardcoded values (`MAX_KEM_NUM` and `MAX_SIG_NUM`) in its source code.

By default, the main setup script will attempt to detect and patch these values automatically in the `s_speed` tool's source code. However, if you wish to manually set a custom value (or if auto-patching fails), you can use the following flag:

```
./setup.sh --set-speed-new-value=[integer]
```

Replace [integer] with the desired value. The setup script will then patch the speed.c source file to set both `MAX_KEM_NUM` and `MAX_SIG_NUM` to this value before compiling OpenSSL.

For further details on this issue and the plans to address the problem, please refer to this [git issue](https://github.com/crt26/pqc-evaluation-tools/issues/25) on the repositories page.

## Enabling HQC KEM Algorithms in Liboqs
This project's computational performance benchmarking system relies on PQC implementations from the Liboqs library. Recent versions of Liboqs disable HQC KEM algorithms by default due to a known **IND-CCA2 vulnerability**. The benchmarking suite provides an optional setup flag to re-enable HQC for **benchmarking purposes only**, as a temporary measure until a revised HQC implementation is included in Liboqs version 0.14.0.

To enable HQC, use the following setup flag:

```
./setup.sh --enable-hqc-algs
```

The setup script will display a warning outlining the associated risks when this flag is provided. Explicit user confirmation is required before HQC algorithms are included in the Liboqs build.

If enabled, the setup script will:
- Pass the appropriate CMake flag to Liboqs to include HQC algorithms.
- Create a temporary marker file (`.hqc_enabled.flag`) in the `tmp` directory to track that HQC is enabled.
- Ensure internal tools, such as the `get_algorithms.py` utility script, detect this marker and include HQC in the generated algorithm list text files.

**Important:** If HQC is enabled, the resulting Liboqs build should only be used within this project's benchmarking tools. It must not be used for anything other than its intended purpose.

For additional context, please see:
- [Liboqs Pull Request #2122](https://github.com/open-quantum-safe/liboqs/pull/2122)
- [Liboqs Issue #2118](https://github.com/open-quantum-safe/liboqs/issues/2118)
- [PQC-Evaluation-Tools Issue #46](https://github.com/crt26/pqc-evaluation-tools/issues/46)
- [Disclaimer Document](../DISCLAIMER.md)