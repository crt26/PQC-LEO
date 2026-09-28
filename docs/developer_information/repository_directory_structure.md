# Repository Directory Structure

## Overview
This document outlines the directory structure of the `PQC-LEO` repository. It includes both the default contents available upon cloning and the directories that are dynamically generated during operation.

Directories created by scripts during execution are marked with an asterisk (`*`) in the directory layout diagram.

## Layout and Descriptions
The `PQC-LEO` repository directories are organised as follows:

```
PQC-LEO/
│
├── docs/
│   ├── _doc_images/
│   ├── developer_information/
│   │   └── energy_collector_APIs/
│   ├── energy_meter_guides/
│   │   └── supported_meters/
│   ├── performance_results/
│   ├── project_tools_guides/
│   ├── testing_tools_usage/
│   │   └── energy_usage_testing_guides/
│
├── lib/ *
│
├── modded_lib_files/
│
├── scripts/
│   ├── parsing_scripts/
│   │   └── internal_scripts/
│   ├── test_scripts/
│   │   └── internal_scripts/
│   └── utility_scripts/
│
├── test_data/ *
│   ├── alg_lists/ *
│   ├── results/ *
│   └── up_results/ *
│
├── tmp/ *
│
└── tools/
    ├── comp_energy_tester/
    └── energy_collector/

```

### Directory Descriptions

| **Name**                      | **Subdirectory (*)**      | **Auto-Generated (*)** | **Description**                                                                                                                               |
|-------------------------------|---------------------------|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `docs`                        |                           |                        | Contains documentation files related to the project.                                                                                          |
| `_doc_images`                 | * (docs)                  |                        | Stores image assets used by project documentation.                                                                                            |
| `developer_information`       | * (docs)                  |                        | Developer guides and references for the project.                                                                                              |
| `energy_collector_APIs`       | * (developer_information) |                        | API documentation and references for the energy collector components.                                                                         |
| `energy_meter_guides`         | * (docs)                  |                        | Guides and documentation for supported and tested energy meters.                                                                              |
| `supported_meters`            | * (energy_meter_guides)   |                        | Meter-specific support notes and setup guidance.                                                                                              |
| `performance_results`         | * (docs)                  |                        | Contains documentation related to result parsing usage and performance metric definitions.                                                    |
| `project_tools_guides`        | * (docs)                  |                        | Usage guides for included project tools.                                                                                                      |
| `testing_tools_usage`         | * (docs)                  |                        | Guides and usage docs for the automated testing tools.                                                                                        |
| `energy_usage_testing_guides` | * (testing_tools_usage)   |                        | Detailed guides for energy usage testing types and related tools.                                                                             |
| `lib`                         |                           |            *           | Populated during setup; contains libraries used for performance testing, including liboqs, oqs-provider, OpenSSL, and included project tools. |
| `modded_lib_files`            |                           |                        | Contains modified files from the OQS project, adapted for this repository's functionality.                                                    |
| `scripts`                     |                           |                        | Contains core scripts used throughout the project.                                                                                            |
| `parsing_scripts`             | * (scripts)               |                        | Scripts for parsing raw benchmarking output from `test_data/up_results`.                                                                      |
| `internal_scripts`            | * (parsing_scripts)       |                        | Internal parsing utilities called by the main parser. Not intended for standalone use.                                                        |
| `test_scripts`                | * (scripts)               |                        | Scripts for running supported performance, transmission cost, and energy usage tests.                                                         |
| `internal_scripts`            | * (test_scripts)          |                        | Internal scripts for the automated performance tests.                                                                                         |
| `utility_scripts`             | * (scripts)               |                        | Project utility scripts used by the various automation scripts.                                                                               |
| `test_data`                   |                           |            *           | Contains input and output data used by the testing framework.                                                                                 |
| `alg_lists`                   | * (test_data)             |            *           | Generated during setup; contains text files listing PQC, Hyrbid-PQC, and classical algorithms used in testing.                                |
| `results`                     | * (test_data)             |            *           | Contains parsed benchmarking results and final structured results written directly by testing scripts.                                        |
| `up_results`                  | * (test_data)             |            *           | Stores raw, unparsed benchmarking output generated by the testing scripts.                                                                    |
| `tmp`                         |                           |            *           | Temporary directory created during script execution for intermediate files and environment flags.                                             |
| `tools`                       |                           |                        | Contains source code for various tools included with PQC-LEO.                                                                                 |
| `comp_energy_tester`          | * (tools)                 |                        | Source code for the PQC computational energy usage measurement tool.                                                                          |
| `energy_collector`            | * (tools)                 |                        | Source for the energy usage collector tools.                                                                                                  |