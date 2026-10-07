# Computational Energy Tester Tool Usage Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a comprehensive guide for using the computational energy tester tool included within PQC-LEO. It covers the general requirements for using the tool, details on how to run the tool, and important information regarding system fan control for energy usage testing. Whilst it is recommended to use the automated energy usage testing scripts provided by PQC-LEO, this document provides information on how to use the computational energy tester tool independently of the automated testing scripts.

If you prefer to make use of the automated energy usage testing provided by PQC-LEO instead of using this tool manually, please refer to the [Energy Usage Testing Guide](../testing_tools_usage/pqc_energy_usage_testing.md) for information on how to use the automated energy usage testing scripts.

### Contents <!-- omit from toc -->
- [Tool Description](#tool-description)
- [Setting up the Computational Energy Usage Testing Tool](#setting-up-the-computational-energy-usage-testing-tool)
- [Tool Usage](#tool-usage)
  - [Running the Energy Usage Testing](#running-the-energy-usage-testing)
  - [Configuring the Testing Parameters](#configuring-the-testing-parameters)
- [Advanced Options](#advanced-options)
  - [Configuring Network Controller Ports](#configuring-network-controller-ports)
  - [Skipping the Welcome Message](#skipping-the-welcome-message)

## Tool Description
The computational energy usage testing tool provides a means of evaluating the energy usage of the cryptographic operations of the various PQC algorithms supported by the PQC-LEO framework. It utilises the PQC implementations available within the Liboqs library and the controller API functions included within the `energy usage collector` tool to perform the energy usage testing.

Whilst PQC-LEO provides an automation script to perform the computational energy usage testing using this tool, it can also be used as a standalone tool to perform the energy usage testing of the PQC algorithms supported by the Liboqs library.

The tool and its source code can be found in the following directory from the PQC-LEO project root directory:

`tools/comp_energy_tester`

## Setting up the Computational Energy Usage Testing Tool
The computational energy usage testing by default is built when energy usage testing is enabled in the PQC-LEO setup script. However, if you wish to build the tool manually, this can be done but you will need to ensure that the Liboqs library is built already in the PQC-LEO `lib` directory. This can be done by running the setup script and selecting installation mode 1.

It is also important to note that the computational energy usage testing tool cannot be built by itself, the `energy_collector` tool included within PQC-LEO must also be built as the computational energy usage testing tool utilises the controller API functions included within the `energy_collector` tool to perform the energy usage testing. The main makefile that is located in the PQC-LEO `tools` directory will automatically build the `energy_collector` tool when the computational energy usage testing tool is built.

To be compiled, the computational energy usage testing tool relies on the following libraries:

- liboqs
- `libcontroller_api.a` (from the energy collector tool)
- `libmeter_api.a` (from the energy collector tool)
- OpenSSL Version 3.3.0 or higher
- libserialport (`libserialport-dev`)

To compile the computational energy usage testing tool with the system OpenSSL, you can run the following commands from PQC-LEO project root directory. Clean the build directories before compiling, including when changing OpenSSL installations:

```bash
cd tools
make
```

To use a custom OpenSSL installation, replace `make` with `make OPENSSL_PATH=/path/to/openssl`, using an absolute path (for the PQC-LEO build, the project's `lib/openssl_4.0.3` directory). This setting applies to both tools. See [OpenSSL Compatibility for Energy Tools](../developer_information/project_dependencies.md#openssl-compatibility-for-energy-tools) for the requirements.

The compiled binaries will then be located in the `tools/comp_energy_tester/build/bin` directory.

Before running the tool manually with the project or custom OpenSSL, add its corresponding `lib64` or `lib` directory to `LD_LIBRARY_PATH`, as shown in the [Energy Collector Tool Usage Guide](energy_collector_usage_guide.md#building-the-energy-usage-collector-tools). The automated `pqc_performance_energy_test.sh` script configures this path for the project build automatically when not using the system OpenSSL.

## Tool Usage

### Running the Energy Usage Testing
The tool can be used to perform the computational energy usage testing of the PQC algorithms supported by the Liboqs library. Before using this tool manually, please refer to the [Energy Usage Testing Guide](../testing_tools_usage/pqc_energy_usage_testing.md) for information on how to setup the energy meter and collection machine. If you wish to use this tool independently of the supported environments by PQC-LEO, you can refer to the [Energy Collector Tool Usage Guide](../project_tools_guides/energy_collector_usage_guide.md), [Controller API Guide](../developer_information/energy_collector_APIs/controller_api_guide.md) and [Meter API Guide](../developer_information/energy_collector_APIs/meter_api_guide.md) for information on how to utilise the energy collector tool's functionality with the computational energy usage testing tool.

Once the energy usage testing environment is setup, you can run the computational energy usage testing tool by running the following command from wherever the compiled binaries are located:

```bash
./comp_energy_tester
```

Once the tool has started, it will then prompt the user to configure the controller and testing parameters.

It is **important to note** that when running the testing tool manually, no changes are made to the system performance state unlike the automated testing method. It is recommended to manually set the system performance and fan speed (if applicable) to a set fixed value to ensure that variances in these parameters do not affect the base system power draw during the energy usage testing. Please refer to the relevant system documentation for information on how to set the system performance state and fan speed.

### Configuring the Testing Parameters
Before testing begins, the script will prompt the user to configure two categories of parameters, which include:

- The Control Signaller
- The Testing Parameters

#### Control Signaller Configuration:
The first set of parameters to be configured is related to the control signaller, which is responsible for signalling the collection machine to poll the energy meter at the appropriate times during the testing process. The user will be prompted to select the control signalling method that they wish to use, with the following options available:

1) Serial
2) Network 

If the user selects serial, the serial port to be used for serial communication must be specified. If the user selects network, the local IP of the testing machine and the remote IP of the collection machine must be specified. For details on setting up the required communication environment for control signalling, please refer to the [Energy Usage Testing](../testing_tools_usage/pqc_energy_usage_testing.md) documentation.

#### Testing Parameter Configuration:
The second set of parameters to be configured is related to the testing parameters, which include:

| **Prompt**                                                                          | **What the option sets**                                                                              |
|-------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| Enter the number of iterations for each test (e.g., 1000)                           | Number of iterations to be performed for each algorithm's respective cryptographic operations.        |
| Enter the number of test runs to perform                                            | Number of separate test runs to execute for averaging.                                                |
| Enter the energy meter polling rate in milliseconds (0 for no delays between polls) | Polling interval in milliseconds for the energy meter; set `0` for continuous/no delay between polls. |

## Advanced Options
The tool allows for the following advanced settings:

- Setting custom network controller listening ports
- Skipping the display of the welcome message

### Configuring Network Controller Ports
The computational energy usage testing tool also provides the ability to configure the network ports used for the control signalling functionality. This can be done by passing the following command line arguments to the tool:

`-c | --use-custom-net-control-ports`

For example:
```bash
./comp_energy_tester -c
```

This will then prompt the user to configure the local and remote network ports to be used for the control signalling functionality if networking communication is selected.

### Skipping the Welcome Message
For automation purposes, the tool supports skipping the display of the welcome message through a command line argument:

`-s | --skip-welcome-message`

For example:

```bash
./comp_energy_tester -s
```

This allows automation scripts that call the tool to display their own welcome message, if the output formatting would benefit from that feature.
