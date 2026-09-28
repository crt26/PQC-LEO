# PQC TLS Handshake Energy Usage Testing Guide <!-- omit from toc -->
This document serves as a comprehensive guide for conducting the automated TLS handshake energy usage testing using the tools provided by PQC-LEO. It covers the general requirements for using the testing scripts and details on how to run the testing script.

Please ensure you have read through the information provided within the main [Energy Usage Testing Guide](../../testing_tools_usage/pqc_energy_usage_testing.md) before proceeding, as it provides important information on setting up and configuring the overall testing environment.

### Contents <!-- omit from toc -->
- [Testing Tool Overview](#testing-tool-overview)
- [Differences from Standard TLS Handshake Testing](#differences-from-standard-tls-handshake-testing)
- [Preparing the Testing Environment](#preparing-the-testing-environment)
- [Running the TLS Handshake Energy Usage Testing](#running-the-tls-handshake-energy-usage-testing)
- [Configuring the Testing Parameters](#configuring-the-testing-parameters)
- [Outputted Results](#outputted-results)

## Testing Tool Overview
The automated TLS handshake energy usage testing utilises the same automation scripts that are used for standard TLS handshake testing, with additional functionality for energy usage testing. The main script responsible for conducting the TLS handshake energy usage testing is the `pqc_tls_performance_test.sh` script located in the `scripts/test_scripts` directory. The automated energy usage testing functionality is integrated into the existing TLS handshake testing when the relevant command line argument `--enable-energy-testing` is passed to the script, which enables the energy usage testing features.

This testing provides insight into the energy usage of using PQC, Hybrid-PQC, and classical algorithms within the context of a TLS handshake. As part of the testing process, the script will automatically handle configuring the system state for energy usage testing, which includes setting the CPU performance to maximum and selecting a specific target CPU core*. This ensures consistent testing conditions for energy usage evaluation, preventing spikes or dips in energy usage due to background processes or thermal throttling. Additionally, a **10 second** baseline energy usage reading is taken before the testing process begins, which serves as a reference point for evaluating the energy consumption of the cryptographic operations.

Energy usage metrics are stored on the collection machine, and will be automatically parsed into structured CSV files for analysis.

>***Notice:** Support for automated configuration of a system fan is not currently available in the provided testing scripts. This is due to the variety of system types and fan control methods available, making a universal solution challenging. Future versions aim to address this limitation. It is **highly recommended** to manually configure the system fan (if applicable) to a fixed speed before testing to prevent variances in the fan speed during testing impacting the systems power draw, skewing the energy usage results.

## Differences from Standard TLS Handshake Testing
Whilst the TLS handshake energy usage testing utilises the same testing scripts and general testing process as the standard TLS handshake testing, there are some differences to be aware of when using the TLS handshake energy usage testing compared to the standard TLS handshake testing. These differences include:

- TLS speed testing is not performed on the client machine when energy usages testing is enabled

- By default, the handshake performance results are not stored as they would be during standard TLS handshake testing. Only the energy usage metrics are collected and stored for parsing and analysis on the collection machine. The user can also store the handshake performance results by selecting yes when prompted during client machine configuration by the TLS testing automation script.

> **Please note:** If you choose to store the handshake performance results, writing these results to disk will be included in the energy usage metrics. Keep this in mind when analysing the energy usage metrics.

## Preparing the Testing Environment
The automated TLS handshake energy usage testing utilises the same automation scripts that are used for standard TLS handshake testing, with additional functionality for energy usage testing. Therefore, the environment setup for this category of testing is the same as the environment setup for the standard TLS handshake testing, with the addition of setting up the energy meter and collection machine for energy usage testing.

It is advised that you first configure the energy meter and collection machine for energy usage testing and then configure the TLS handshake testing. Once you have reached the point of enabling the client machine for TLS handshake testing, please return to this guide to continue with enabling the energy usage testing functionality for the TLS handshake testing.

Please refer to the [TLS Performance Testing Guide](../tls_performance_testing.md) for details on setting up the environment for TLS handshake testing, and refer to the [Energy Usage Testing Guide](../pqc_energy_usage_testing.md) for details on setting up the energy meter and collection machine for energy usage testing.

## Running the TLS Handshake Energy Usage Testing
The TLS handshake energy usage testing follows the same overall process as the standard TLS handshake testing. The only additional step is to launch the energy metric collector script on the collection machine and configure it for TLS handshake energy usage testing. For the standard TLS handshake testing setup and execution steps, refer to the [TLS Performance Testing Guide](../tls_performance_testing.md).

When initiating the collection machine script, please ensure to select the `TLS Handshake Performance Energy Testing` collection type when prompted by the script. This will ensure that the collection machine is configured for TLS handshake energy usage testing.

Once the collection machine is configured and the server machine is ready for TLS handshake testing, run the test script on the client machine as usual, but include the `--enable-energy-testing` flag when calling the `pqc_tls_performance_test.sh` script.

This flag enables the energy usage testing functionality within the script. It allows the client-side test script to signal the collection machine to poll the energy meter at the appropriate points during testing, while also ensuring that the system state is configured correctly for energy usage measurements.

Example command on the client machine:

```bash
./pqc_tls_performance_test.sh --enable-energy-testing
```

## Configuring the Testing Parameters
The testing parameters for TLS handshake energy usage testing are configured using the same general process as standard TLS handshake testing. However, some standard TLS handshake testing parameters do not apply, and additional energy usage testing parameters must be configured when the `--enable-energy-testing` flag is passed to the client-side testing script.

During client configuration, the script asks whether the TLS handshake performance results should also be stored on the client machine. Selecting no retains the default energy-only behaviour. Selecting yes enables client-side storage and parsing of the handshake performance results.

The following standard TLS performance testing parameters are handled differently when energy usage testing is enabled:

- Machine-ID configuration is requested only when TLS handshake performance results will be stored on the client machine. The Machine-ID for the energy usage results is configured independently on the collection machine.

- TLS speed testing parameters are excluded because TLS speed testing is not performed in this mode.

Once the applicable standard TLS handshake testing parameters have been configured, the control signaller parameters can be set. The control signaller is responsible for signalling the collection machine to poll the energy meter at the appropriate points during the testing process.

The user will be prompted to select one of the following control signalling methods:

1. Serial
2. Network

If serial signalling is selected, the COM port used for serial communication must be specified. If network signalling is selected, both the local IP address of the testing machine and the remote IP address of the collection machine must be specified.

For details on setting up the required communication environment for control signalling, refer to the [Energy Usage Testing Guide](../../testing_tools_usage/pqc_energy_usage_testing.md).

## Outputted Results
After testing completes, the raw output from the TLS handshake energy usage testing is stored on the collection machine in:

`test_data/up_results/energy_test_results/tls_handshake_energy_results/machine_x`

Where `machine_x` refers to the assigned Machine-ID. If no ID was specified, the default ID of 1 is used.

By default, the automated collection script will trigger the parsing system upon completion of testing, which processes the raw energy usage output into structured CSV files. These parsed results are saved in:

`test_data/results/energy_test_results/tls_handshake_energy_results/machine_x`

The parsed TLS handshake energy results are separated into `classic`, `pqc`, and `hybrid_pqc` subdirectories.

If the user chooses to retain the TLS handshake performance results during client configuration, the raw results are stored on the client machine in:

`test_data/up_results/tls_performance/machine_x`

The PQC TLS testing script automatically parses these handshake results while skipping TLS speed parsing. The parsed performance results are stored in:

`test_data/results/tls_performance/machine_x`

The energy usage results on the collection machine and the optional handshake performance results on the client machine are parsed independently.

To skip automatic parsing and only output the raw test results, pass the `--disable-result-parsing` flag when launching the collection machine script:

```
./energy_metric_collector.sh --disable-result-parsing
```

For complete details on parsing functionality and a breakdown of the collected energy usage metrics, refer to the following documentation:

- [Parsing Performance Results Usage Guide](../../performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](../../performance_results/performance_metrics_guide.md)
