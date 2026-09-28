# Parsing Scripts Usage Guide <!-- omit from toc -->

## Document Overview <!-- omit from toc -->
This document provides a comprehensive guide to the usage of the result parsing functionality included in the PQC-LEO project. It explains how the parsing system processes raw benchmarking output data into structured results, and how users can interact with the parsing system in both automated and manual modes.

It also outlines the expected directory structure for test results, limitations of the current implementation, and how to manually invoke the parsing process using the provided Python scripts.

### Contents <!-- omit from toc -->
- [Parsing Overview](#parsing-overview)
- [Automatic Parsing](#automatic-parsing)
- [Manual Parsing](#manual-parsing)
  - [Interactive Parsing](#interactive-parsing)
  - [Command-Line Parsing](#command-line-parsing)
- [Additional Information on Energy Usage Result Parsing](#additional-information-on-energy-usage-result-parsing)
- [Parsed Results Output](#parsed-results-output)
- [Current Parsing Limitations](#current-parsing-limitations)

## Parsing Overview
The parsing system in PQC-LEO transforms raw test output into structured CSV files that are ready for analysis. Parsing can happen automatically at the end of each test run or be invoked manually later using the provided controller script. Parsed results are categorised by test type (computational performance or TLS performance) and Machine-ID, and are saved into separate result folders under the main `test_data` directory.

The automated testing scripts provided by this project will automatically call the Python parsing scripts once testing is completed and supply the testing parameters used. However, the user may decide to disable this feature and call the parsing scripts manually.

The following sections describe how to use the available parsing methods and what to expect from each.

## Automatic Parsing
When a testing script completes, the parsing process is triggered automatically. The script passes the assigned Machine-ID and number of test runs to the parsing tool, which then processes the raw result files and generates structured CSV files. This automatic process is designed to simplify result management and ensure consistency without requiring any additional user input.

To disable automatic parsing, pass the `--disable-result-parsing` flag to the test script. For example:

```
./pqc_performance_test.sh --disable-result-parsing
```

This defers parsing so it can be triggered interactively or via command-line flags later.

## Manual Parsing
While automatic parsing is recommended in most cases, manual parsing is fully supported and can be performed using one of two methods:

- **Interactive mode** — The user is prompted to enter parameters via the terminal.

- **Command-line arguments** — Parsing parameters are passed directly as script flags.

**Note:** If performing manual parsing in a separate environment from where the tests were run, the script requires access to the same algorithm list files used during testing. Please make sure these files are present in the expected directories before proceeding.

### Interactive Parsing
To use the interactive parsing method, call the parsing script using the following command:

```
python3 parse_results.py
```

You will be prompted to select a parsing mode:

- Parse computational performance results
- Parse TLS performance results
- Parse energy usage results

After selecting a mode, the script will ask for the Machine-ID and the number of test runs for each result type. Additionally, if the TLS performance parsing mode is selected, the script will ask whether TLS speed parsing should be skipped. This is necessary when energy usage testing has been performed for TLS handshake operations, and the user has chosen to store the performance results alongside the energy usage results.

If the energy usage results parsing mode is selected, the script will also ask for the energy testing type that should be parsed. The following options are currently supported:

- PQC computational energy usage
- TLS handshake energy usage
- TLS speed energy usage

Once all required parameters are provided, the script will then process the appropriate raw result files and generate structured CSV outputs.

The interactive parsing method is ideal when manually parsing results or combining both result types in a single operation, which is not supported via the command-line interface.

### Command-Line Parsing
Parsing parameters can also be supplied directly as command-line arguments. This is the method used by the test scripts to perform automatic parsing unless the `--disable-result-parsing` flag is specified.

Command-line mode can also be executed manually, as seen in the example below:

```
python3 parse_results.py --parse-mode=computational --machine-id=2 --total-runs=10
```

The table below outlines each of the accepted commands that are required for operation:

| **Argument**               | **Description**                                                                                              | **Required Flag (*)** |
|----------------------------|--------------------------------------------------------------------------------------------------------------|-----------------------|
| `--parse-mode=<str>`       | Must be `computational`, `tls`, or `energy`.                                                                 |           *           |
| `--machine-id=<int>`       | Machine-ID used during testing (positive integer).                                                           |           *           |
| `--total-runs=<int>`       | Number of test runs (must be > 0).                                                                           |           *           |
| `--energy-test-type=<int>` | Required when `--parse-mode=energy`. 1=PQC computational energy, 2=TLS handshake energy, 3=TLS speed energy. |                       |
| `--replace-old-results`    | Optional flag to force overwrite any existing results for the specified Machine-ID.                          |                       |
| `--skip-tls-speed`         | When `--parse-mode=tls`, skips TLS speed parsing. Use when energy testing produces handshake results only.   |                       |

This mode is suited for automated testing workflows or environments where manual input is impractical.

## Additional Information on Energy Usage Result Parsing
As part of the automation scripts provided by PQC-LEO for PQC energy usage testing, generated raw result files are automatically organised and named to ensure compatibility with the parsing system. However, due to the flexibility of the [energy evaluation tools](../project_tools_guides/energy_collector_usage_guide.md) when used outside of these automation scripts, additional information on how the automated parsing system handles energy usage results is provided below.

Unlike the other parsing scripts, which utilise a combination of predefined algorithm lists and filename contents, the energy usage parsing system extracts all test parameters and metadata directly from the result filename. Because of this, raw result files generated independently of the provided automation scripts may not be compatible with the existing parsing system.

Currently, the energy usage parsing scripts expect specific testing categories and corresponding filename structures. If the energy evaluation tools are used outside of the provided automation scripts, the following filename requirements must be followed in order to use the existing parsing scripts successfully. Otherwise, raw result files will need to be processed manually. Future releases of PQC-LEO aim to improve the flexibility of the parsing system to better support dynamically generated and custom result files.

The automated energy usage result parsing scripts support processing for the following testing types:

- PQC computational energy usage
- TLS handshake energy usage
- TLS speed energy usage

For each of these testing types, the following filename structure is expected:
- **Computational Energy Usage Result** - `comp_(alg-type)_(operation)_(alg-name)_(run-number).txt`
- **TLS Handshake Energy Usage Result** - `tls_handshake_(session-id-type)_(signing-alg)@(kem-alg)_(run-number).txt`
- **TLS Speed Energy Usage Result** - `tls_speed_(alg-type)_(operation)_(alg-name)_(run-number).txt`

## Parsed Results Output
Once parsing is complete, the parsed results will be stored in the newly created `test_data/results` directory. This includes CSV files containing the detailed test results and automatically calculated averages for each test category. These files are ready for further analysis or can be imported into graphing tools for visualisation.

The output is organised by test type and Machine-ID in the following directories:

- `test_data/results/computational_performance/machine_x`
- `test_data/results/tls_performance/machine_x`
- `test_data/results/energy_test_results/[test_type]/machine_x`

`machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be used.

For energy usage testing results, `test_type` refers to one of the following testing categories based on the type of results that were parsed:

- `pqc_performance_energy_results`
- `tls_handshake_energy_results`
- `tls_speed_energy_results`

Please refer to the [Performance Metrics Guide](./performance_metrics_guide.md) for a detailed description of the performance metrics that this project can gather, what they mean, and how these scripts structure the unparsed and parsed data.

## Current Parsing Limitations
The current implementation of the parsing system includes several known limitations:

- Only one **Machine-ID** can be parsed at a time. You must run the script separately to parse results from multiple machines.

- Only one **parsing mode** can be performed per execution of the parsing script.

- Parsing depends on access to the original algorithm list files used during testing. When parsing is performed on a different machine, the testing environment must be replicated to ensure compatibility. This does not apply to energy usage parsing, which extracts all necessary information from the result filename.

- Energy usage parsing expects specific testing categories and filename formats. Any deviation from this structure may result in parsing failures or incorrect outputs and manual processing will be required.

These limitations will be addressed in future updates to improve flexibility and cross-system compatibility