# Advanced Setup Configurations
This document outlines additional configuration options available when running the `setup.sh` script. The script supports the following advanced configurations:

- Use the latest versions of the OQS dependency libraries
- Manually adjusting OpenSSL's `speed` tool hardcoded limits
- Enabling Liboqs algorithm memory optimisation for supported algorithms

## Using the Latest Versions of the OQS Libraries
By default, the setup process uses specific pinned commits of the OQS libraries that correspond to the last tested repository state verified for compatibility with this project's automation tools. However, users may opt to use the latest upstream versions of the dependencies by passing the following flag to the setup script:

```
./setup.sh --latest-dependency-versions
```

This option may provide access to the most recent algorithm updates and bug fixes, but it may also introduce breaking changes due to upstream modifications. The setup script will display a warning and require explicit confirmation before proceeding with the latest versions.

For more information on the specific versions used by default, see the [Project Dependencies](./developer_information/project_dependencies.md) documentation.

## Adjusting OpenSSL Speed Tool Hardcoded Limits
When using either the `full` or `TLS-only` install modes, an optional prompt will appear that allows enabling all algorithms in the OQS-Provider library supported by PQC-LEO that are disabled by default.

By default, the main setup script will attempt to detect and patch these values automatically in the `speed` tool's source code to increase the hardcoded limits if needed. However, if you wish to manually set a custom value (or if auto-patching fails), you can use the following flag:

```
./setup.sh --set-speed-new-value=[integer]
```

Replace [integer] with the desired value. The setup script will then patch the `speed.c` source file to set both `MAX_KEM_NUM` and `MAX_SIG_NUM` to this value before compiling OpenSSL.

For further details on this issue and the plans to address the problem in the future, please refer to this [git issue](https://github.com/crt26/PQC-LEO/issues/25) on the repositories page.

## Enabling Liboqs Algorithm Memory Optimisation
As of version 0.16.0 of the Liboqs library, support for using memory optimised implementations of supported algorithms has been added. These implementations reduce the memory footprint of certain algorithms, but may impact their overall performance. By default, this feature is disabled during the setup process but can be enabled should the user wish to utilise this Liboqs feature.

If the user wishes to utilise this feature in Liboqs, the `--liboqs-memory-optimisation` flag can be passed to the `setup.sh` script:

```
./setup.sh --liboqs-memory-optimisation
```

As described within the [Liboqs documentation](https://github.com/open-quantum-safe/liboqs/blob/5a1a854b0dc9f2141bdc771c555ee60c37950183/CONFIGURE.md#oqs_memopt_build), when the `-DOQS_MEMOPT_BUILD=ON` flag is passed to the Liboqs build process, algorithms with memory optimised implementations will be used where available. If an algorithm does not have a memory optimised implementation, the standard implementation will be used instead.