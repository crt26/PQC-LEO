# Parsing Scripts Usage Guide <!-- omit from toc -->

## Document Overview <!-- omit from toc -->
This document provides a comprehensive guide to the usage of the result parsing functionality included in the PQC-Evaluation-Tools project. It explains how the parsing system processes raw benchmarking output data into structured results, and how users can interact with the parsing system in both automated and manual modes.

It also outlines the expected directory structure for test results, limitations of the current implementation, and how to manually invoke the parsing process using the provided Python scripts.

### Contents <!-- omit from toc -->
- [Parsing Overview](#parsing-overview)
- [Automatic Parsing](#automatic-parsing)
- [Manual Parsing](#manual-parsing)
  - [Interactive Parsing](#interactive-parsing)
  - [Command-Line Parsing](#command-line-parsing)
- [Parsed Results Output](#parsed-results-output)
- [Current Parsing Limitations](#current-parsing-limitations)

## Parsing Overview
The parsing system in PQC-Evaluation-Tools transforms raw test output into structured CSV files that are ready for analysis. Parsing can happen automatically at the end of each test run or be invoked manually later using the provided controller script. Parsed results are categorised by test type (computational performance or TLS performance) and Machine-ID, and are saved into separate result folders under the main `test_data` directory.

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

**Note:** If performing manual parsing in a separate environment from where the tests were ran, the script requires access to the same algorithm list files used during testing. Please make sure these files are present in the expected directories before proceeding.

### Interactive Parsing
To use the interactive parsing method, call the parsing script using the following command:

```
python3 parse_results.py
```

You will be prompted to select a parsing mode:

- Parse computational performance results
- Parse TLS performance results
- Parse both computational and TLS performance results

After selecting a mode, the script will ask for the Machine-ID and the number of test runs for each result type. It will then process the appropriate raw result files and generate structured CSV outputs.

This method is ideal when manually parsing results or combining both result types in a single operation, which is not supported via the command-line interface.

### Command-Line Parsing
Parsing parameters can also be supplied directly as command-line arguments. This is the method used by the test scripts to perform automatic parsing unless the `--disable-result-parsing` flag is specified.

Command-line mode can also be executed manually, as seen in the example below:

```
python3 parse_results.py --parse-mode=computational --machine-id=2 --total-runs=10
```

The table below outlines each of the accepted commands that are required for operation:

| **Argument**            | **Description**                                                                        | **Required Flag (*)** |
|-------------------------|----------------------------------------------------------------------------------------|-----------------------|
| `--parse-mode=<str>`    | Must be either computational or tls, both is not allowed here.                         | *                     |
| `--machine-id=<int>`    | Machine-ID used during testing (positive integer).                                     | *                     |
| `--total-runs=<int>`    | Number of test runs (must be > 0).                                                     | *                     |
| `--replace-old-results` | Optional flag to force overwrite of any existing results for the specified Machine-ID. |                       |

This mode is suited for automated workflows or environments where manual input is impractical.

**Note:** The `--parse-mode` argument cannot be set to both. If you wish to parse both computational and TLS performance results in one session, you must use the script in interactive mode.

## Parsed Results Output
Once parsing is complete, the parsed results will be stored in the newly created `test_data/results` directory. This includes CSV files containing the detailed test results and automatically calculated averages for each test category. These files are ready for further analysis or can be imported into graphing tools for visualisation.

The output is organised by test type and Machine-ID in the following directories:

- `test_data/results/computational_performance/machine_x`
- `test-data/results/tls_performance/machine_x`

Where `machine_x` is the Machine-ID number assigned to the results when executing the testing scripts. If no custom Machine-ID is assigned, the default ID of 1 will be used.

Please refer to the [Performance Metrics Guide](./performance_metrics_guide.md) for a detailed description of the performance metrics that this project can gather, what they mean, and how these scripts structure the un-parsed and parsed data.

## Current Parsing Limitations
The current implementation of the parsing system includes several known limitations:

- Only one **Machine-ID** can be parsed at a time per mode. You must run the script separately to parse results from multiple machines.

- Parsing both computational and TLS results in a single run is supported only in **interactive mode**.

- Parsing depends on access to the original algorithm list files used during testing. When parsing is performed on a different machine, the testing environment must be replicated to ensure compatibility.

These limitations will be addressed in future updates to improve flexibility and cross-system compatibility