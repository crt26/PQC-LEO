# Automated PQC Computational Performance Benchmarking Tool - Usage Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This guide provides detailed instructions for using the automated Post-Quantum Cryptographic (PQC) computational performance testing tool. It allows users to gather benchmarking data for PQC algorithms using the Open Quantum Safe (OQS) Liboqs library. It automatically collects raw performance data in CSV and text formats, which can then be parsed into structured, analysis-ready results using the included Python scripts.

### Contents <!-- omit from toc -->
- [Supported Hardware](#supported-hardware)
- [Supported PQC Algorithms](#supported-pqc-algorithms)
- [Performing PQC Computational Performance Testing](#performing-pqc-computational-performance-testing)
  - [Running the Testing Script](#running-the-testing-script)
  - [Configuring Testing Parameters](#configuring-testing-parameters)
- [Outputted Results](#outputted-results)
- [Useful External Documentation](#useful-external-documentation)

## Supported Hardware
The automated testing tool is currently only supported on the following devices:

- x86 Linux Machines using a Debian-based operating system
- ARM Linux devices using a 64-bit Debian-based Operating System

## Supported PQC Algorithms
This tool supports all PQC algorithms available through the Liboqs library. However, there are some limitations to this that should be considered when using the computational performance testing tool. 

For a full list of algorithms currently supported in this project’s performance testing suite, see:

[Supported Algorithms](../supported_algorithms.md)

**Notice:** The HQC KEM algorithms are disabled by default in recent versions of both Liboqs and the OQS-Provider, due to their current implementations not conforming to the latest specification, which includes important security fixes. For benchmarking purposes, the setup process includes an optional flag to enable HQC in these libraries, accompanied by a user confirmation prompt and warning. Enabling HQC is done at the user's own discretion, and this project assumes no responsibility for its use. For instructions on enabling HQC, see the [Advanced Setup Configuration Guide](../advanced_setup_configuration.md), and refer to the [Disclaimer Document](../../DISCLAIMER.md) for more information on this issue.

## Performing PQC Computational Performance Testing

### Running the Testing Script
The automated test script is located in the `scripts/testing_scripts` directory and can be launched using the following command:

```
./pqc_performance_test.sh
```

When executed, the testing script will prompt you to configure the benchmarking parameters.

### Configuring Testing Parameters
Before testing begins, the script will prompt you to configure a few testing parameters, which include:

- Should the results have a custom Machine-ID assigned to them?
- The number of times each test should be run to allow for a more accurate average calculation.

#### Machine Comparison Option <!-- omit from toc -->
The first testing option is:

```
Do you wish to assign a custom Machine-ID to the performance results? [y/n]?
```

Selecting `y` (yes) allows you to assign a Machine-ID, which is used by the parsing scripts to organise and distinguish results from different systems, which is useful for cross-device or cross-architecture comparisons. If you select `n` (no), the default Machine-ID of 1 will be applied.

#### Assigning Number of Test Runs <!-- omit from toc -->
The second testing parameter is the number of test runs that should be performed. The script will present the following option:

```
Enter the number of test runs required:
```

Enter a valid integer to specify how many times each test should run. A higher number of runs will increase the total testing time, especially on resource-constrained devices, but it also improves the accuracy of the resulting performance averages.

## Outputted Results
After testing completes, raw performance results are saved to the following directory:

`test_data/up_results/computational_performance/machine_x`

Where `machine_x` refers to the assigned Machine-ID. If no ID was specified, the default ID of 1 is used.

By default, the testing script will automatically trigger the parsing system upon completion. It passes the Machine-ID and total number of test runs to the parsing tool, which then processes the raw output into structured CSV files.

These parsed results are saved in:

`test_data/results/computational_performance/machine_x`

To skip automatic parsing and only output the raw test results, pass the `--disable-result-parsing` flag when launching the test script:

```
./pqc_performance_test.sh --disable-result-parsing
```

For complete details on parsing functionality and a breakdown of the collected computational performance metrics, refer to the following documentation:

- [Parsing Performance Results Usage Guide](../performance_results/parsing_scripts_usage_guide.md)
- [Performance Metrics Guide](../performance_results/performance_metrics_guide.md)

## Useful External Documentation
- [Liboqs Webpage](https://openquantumsafe.org/liboqs/)
- [Liboqs GitHub Page](https://github.com/open-quantum-safe/liboqs)
- [Latest liboqs Release Notes](https://github.com/open-quantum-safe/liboqs/blob/main/RELEASE.md)
- [Valgrind Massif Tool](http://valgrind.org/docs/manual/ms-manual.html)