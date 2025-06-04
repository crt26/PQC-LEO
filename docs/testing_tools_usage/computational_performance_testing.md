# Automated PQC Computational Performance Benchmarking Tool Usage Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This guide provides detailed instructions for using the automated Post-Quantum Cryptographic (PQC) computational performance testing tool. It allows users to gather benchmarking data for PQC algorithms using the Open Quantum Safe (OQS) Liboqs library as the current backend. Results are collected automatically and can be customised with user-defined test parameters.

The tool outputs raw performance metrics in CSV and text formats, which are later parsed using Python scripts for easier interpretation and analysis.

### Contents <!-- omit from toc -->
- [Supported Hardware and Software](#supported-hardware-and-software)
- [Performing PQC Computational Performance Testing](#performing-pqc-computational-performance-testing)
  - [Running the Testing Script](#running-the-testing-script)
  - [Configuring Testing Parameters](#configuring-testing-parameters)
- [Outputted Results](#outputted-results)
- [Useful External Documentation](#useful-external-documentation)

## Supported Hardware and Software
The automated testing tool is currently only supported on the following devices:

- x86 Linux Machines using a Debian-based operating system
- ARM Linux devices using a 64-bit Debian based Operating System

**Notice:** The HQC KEM algorithms are disabled by default in recent Liboqs versions due to a disclosed IND-CCA2 vulnerability. For benchmarking purposes, the setup process includes an optional flag to enable HQC, accompanied by a user confirmation prompt and warning. For instructions on enabling HQC, see the [Advanced Setup Configuration Guide](../advanced_setup_configuration.md), and refer to the [Disclaimer Document](../../DISCLAIMER.md) for more information on this issue.

## Performing PQC Computational Performance Testing

### Running the Testing Script
The automated test script is located in the `scripts/testing_scripts` directory and can be launched using the following commands:

```
./pqc_performance_test.sh
```

When executed, the testing script will prompt you to configure the benchmarking parameters.

### Configuring Testing Parameters
Before testing begins, the script will prompt you to configure a few testing parameters which includes:

- Whether the results should have a custom Machine-ID assigned to them.
- The number of times each test should be run to allow for more accurate average calculation.

#### Machine Comparison Option <!-- omit from toc -->
The first testing option is:

```
Do you wish to assign a custom Machine-ID to the performance results? [y/n]?
```

Selecting `y` (yes) enables multi-machine result comparison. The script will prompt you to assign a machine ID to the results, which the Python parsing scripts use to organise and differentiate data from different systems. This is useful when comparing performance across devices or architectures. Responding  `n` (no) to this option will assign a default value of `1` to the outputted machine results upon test completion.

#### Assigning Number of Test Runs <!-- omit from toc -->
The second testing parameter is the number of test runs that should be performed. The script will present the following option:

```
Enter the number of test runs required:
```

You can then enter a valid integer value to specify the total number of test runs. However, it is important to note that a higher number of runs will significantly increase testing time, especially if the tool is being used on a more constrained device. This feature allows for sufficient gathering of data to perform average calculations, which is vital if conducting research into the performance of PQC algorithms.

## Outputted Results
After testing completes, raw performance results are saved to the following directory:

`test_data/up_results/computational_performance/machine_x`

Where `machine_x` refers to the assigned Machine-ID. If no ID was specified, the default ID of 1 is used.

By default, the testing script will automatically trigger the parsing system upon completion. It passes the Machine-ID and total number of test runs to the parsing tool, which then processes the raw output into structured CSV files.

These parsed results are saved in:

`test_data/results/computational_performance/machine_x`

To skip automatic parsing and retain only the raw test output, pass the `--disable-result-parsing` flag when launching the test script:

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
- [OQS Benchmarking Webpage](https://openquantumsafe.org/benchmarking/)
- [OQS Profiling Project](https://openquantumsafe.org/benchmarking/)