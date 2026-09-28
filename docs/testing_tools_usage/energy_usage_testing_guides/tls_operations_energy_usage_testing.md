# PQC TLS Operations Energy Usage Testing Guide <!-- omit from toc -->
This document serves as a comprehensive guide for using the automated TLS operations energy usage testing tools provided by PQC-LEO. It covers the general requirements for using the testing scripts and details on how to run the testing script.

Please ensure you have read through the information provided within the main [Energy Usage Testing Guide](../../testing_tools_usage/pqc_energy_usage_testing.md) before proceeding, as it provides important information on setting up and configuring the overall testing environment.

### Contents <!-- omit from toc -->
- [Testing Tool Overview](#testing-tool-overview)
- [Running the TLS Operations Energy Usage Testing](#running-the-tls-operations-energy-usage-testing)
  - [Launching the Collection Machine Script](#launching-the-collection-machine-script)
  - [Launching the Testing Machine Script](#launching-the-testing-machine-script)
- [Configuring the Testing Parameters](#configuring-the-testing-parameters)
- [Outputted Results](#outputted-results)

## Testing Tool Overview
The automated testing script for evaluating TLS operations energy usage is located in the `scripts/test_scripts` directory. Please ensure that the basic environment setup and setup checks have been performed before launching the testing script. For details on environment setup and checks, please refer to the [Energy Usage Testing Guide](../pqc_energy_usage_testing.md).

The provided Bash script uses OpenSSL and the OQS-Provider to automate cryptographic operation testing while an energy collector records the testing machine's energy usage. The generated algorithm lists in `test_data/alg_lists` determine which algorithms are tested. PQC and Hybrid-PQC KEMs are tested for key generation, encapsulation, and decapsulation; PQC, Hybrid-PQC, and classical digital signatures are tested for key generation, signing, and verification; and classical key-exchange algorithms are tested for key generation and shared-secret derivation. Each operation is repeated for a user-configured number of iterations.

The classical signature coverage includes RSA, RSA-PSS, ECDSA, EdDSA, and Brainpool variants. Unlike the standard TLS speed test, this energy test performs the OpenSSL operations directly and can explicitly configure PSS padding. The `RSA_*` categories generate generic RSA keys, while the `RSA-PSS_*` categories generate RSA-PSS-restricted keys; both categories use PSS padding for signing and verification. Classical key-exchange coverage includes X25519, X448, NIST curves, and Brainpool TLS 1.3 groups. See the [Supported Algorithms](../../supported_algorithms.md) guide for the complete lists and the Hybrid-PQC KEM exclusions that apply to this test.

As part of the testing process, the script will automatically handle configuring the system state for energy usage testing, which includes setting the CPU performance to maximum and selecting a specific target CPU core*. This ensures consistent testing conditions for energy usage evaluation, preventing spikes or dips in energy usage due to background processes or thermal throttling. Additionally, a **10 second** baseline energy usage reading is taken before the testing process begins, which serves as a reference point for evaluating the energy consumption of the cryptographic operations.

Energy usage metrics are stored on the collection machine, and will be automatically parsed into structured CSV files for analysis.

>***Notice:** Support for automated configuration of a system fan is not currently available in the provided testing scripts. This is due to the variety of system types and fan control methods available, making a universal solution challenging. Future versions aim to address this limitation. It is **highly recommended** to manually configure the system fan (if applicable) to a fixed speed before testing to prevent variances in the fan speed during testing impacting the systems power draw, skewing the energy usage results.

## Running the TLS Operations Energy Usage Testing
There are two machines and scripts that must be configured and launched for the energy usage testing process, which include: the collection machine and the testing machine. Each machine has its own respective script that must be launched to ensure the testing process runs smoothly, with the testing machine script responsible for signalling the collection machine to poll the energy meter at the appropriate times during testing.

Please ensure you have thoroughly read the general instructions and environment setup for the collection machine in the [Energy Usage Testing Guide](../../testing_tools_usage/pqc_energy_usage_testing.md) before proceeding with testing, as it contains important details on setting up the collection machine and energy meter for testing.

### Launching the Collection Machine Script
Once the environment for the collection machine is properly set up, the collection machine script can be launched using the following command:

```
./energy_metric_collector.sh
```

Please then select the `TLS Operations Energy Testing` collection type and proceed to configure the relevant collection parameters as prompted by the script. For details on configuring the collection parameters, please refer to the [Energy Usage Testing Guide](../../testing_tools_usage/pqc_energy_usage_testing.md).

### Launching the Testing Machine Script
Once the environment is ready and the collection machine has been activated, the testing machine script can be launched using the following command:

```
./tls_operations_energy_test.sh
```

Additional command line arguments can be passed to the testing script which enable advanced customisation of the automated testing process. For details of all advanced testing options, please refer to the [Energy Usage Testing Guide](../pqc_energy_usage_testing.md#advanced-testing-options). Of these advanced options, the ones supported by the TLS operations energy usage script are:

- `--use-custom-sys-state`
- `--use-custom-net-control-ports`

## Configuring the Testing Parameters
Before testing begins, the script will prompt the user to configure two categories of parameters, which include:

- The Control Signaller
- The Testing Parameters

#### Control Signaller Configuration:
The first set of parameters to be configured is related to the control signaller, which is responsible for signalling the collection machine to poll the energy meter at the appropriate times during the testing process. The user will be prompted to select the control signalling method that they wish to use, with the following options available:

1) Serial
2) Network 

If the user selects serial, the COM port to be used for serial communication must be specified. If the user selects network, the local IP of the testing machine and the remote IP of the collection machine must be specified. For details on setting up the required communication environment for control signalling, please refer to the [Energy Usage Testing Guide](../pqc_energy_usage_testing.md).

#### Testing Parameter Configuration:
The second set of parameters to be configured is related to the testing parameters, which include:

| **Prompt**                                                                          | **What the option sets**                                                                              |
|-------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| Enter the number of iterations for each test (e.g., 1000)                           | Number of iterations to be performed for each algorithm's respective cryptographic operations.        |
| Enter the number of test runs to perform                                            | Number of separate test runs to execute for averaging.                                                |
| Enter the energy meter polling rate in milliseconds (0 for no delays between polls) | Polling interval in milliseconds for the energy meter; set `0` for continuous/no delay between polls. |

## Outputted Results
After testing completes, the raw output from the TLS operations energy usage testing is stored in:

`test_data/up_results/energy_test_results/tls_operations_energy_results/machine_x`

Where `machine_x` refers to the assigned Machine-ID. If no ID was specified, the default ID of 1 is used.

By default, the automated collection script will trigger the parsing system upon completion of testing, which processes the raw output into structured CSV files. These parsed results are saved in:

`test_data/results/energy_test_results/tls_operations_energy_results/machine_x`

The parser separates results into `pqc`, `hybrid`, and `classic` sub-directories. For every run it produces KEM and signature files for the PQC and Hybrid-PQC groups, and signature and key-exchange files for the classical group. Each detailed per-run CSV has a corresponding `_condensed.csv` summary. For example:

- `pqc/tls_operations_pqc_kem_1.csv`
- `hybrid/tls_operations_hybrid_pqc_sig_1.csv`
- `classic/tls_operations_classic_sig_1.csv`
- `classic/tls_operations_classic_key_exchange_1.csv`

The baseline CSV, `tls_operations_energy_usage_baseline.csv`, remains directly under the machine directory.

To skip automatic parsing and only output the raw test results, pass the `--disable-result-parsing` flag when launching the collection machine script:

```
./energy_metric_collector.sh --disable-result-parsing
```

For complete details on parsing functionality and a breakdown of the collected energy usage metrics, refer to the following documentation:

- [Parsing Performance Results Usage Guide](../../performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](../../performance_results/performance_metrics_guide.md)