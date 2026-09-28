# Integrating New Energy Meters into PQC-LEO <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a developer guide for integrating support for new energy meters into the PQC-LEO energy collector tool. It covers the structure of the meter API, the files that need to be added for a new energy meter backend, and the changes that need to be made so that the new backend can be used through the generic meter API functions.

The guide is intended for developers who want to add support for an energy meter that is not currently supported by PQC-LEO. For detailed information on the generic meter API functions and data structures, please refer to the [Meter API Guide](./meter_api_guide.md).

### Contents <!-- omit from toc -->
- [Quick Integration Checklist](#quick-integration-checklist)
- [Meter API Purpose and Structure](#meter-api-purpose-and-structure)
- [Required Backend Functions for New Energy Meters](#required-backend-functions-for-new-energy-meters)
  - [Overview of Required Functions](#overview-of-required-functions)
- [Adding Energy Meter Backend Files](#adding-energy-meter-backend-files)
- [Mapping Backend Readings to the Generic MeterReading Structure](#mapping-backend-readings-to-the-generic-meterreading-structure)
- [Registering the New Energy Meter Type](#registering-the-new-energy-meter-type)
- [Adding the Generic API Calling Logic](#adding-the-generic-api-calling-logic)
- [Build Behaviour for New Meter Backends](#build-behaviour-for-new-meter-backends)
- [Testing the New Energy Meter Integration](#testing-the-new-energy-meter-integration)
- [Updating Energy Meter Documentation](#updating-energy-meter-documentation)

## Quick Integration Checklist
Use this checklist as a general guide on the steps needed for meter integration. Each step is described in more detail in the following sections:

1. Add new backend files under `_meter_interfaces/include/` and `_meter_interfaces/src/`.
2. Register the new meter in `meter_api.h` (`#include` and `MeterType` enum entry).
3. Add the new meter option in `energy_collector/include/collector.h`.
4. Add `switch` cases in `meter_api.c` for `meter_init()`, `meter_send_cmd()`, `meter_poll()`, and `meter_close()`.
5. Run initialisation, polling, mapping, and close-path tests before marking the meter as supported.
6. Add the new meter to the supported meter list and create a usage guide in `docs/energy_meter_guides/supported_meters/`.

## Meter API Purpose and Structure
The meter API provides an abstraction layer for interacting with the supported energy meters and coordinating the collection of energy usage metrics. This abstraction layer provides a set of unified functions for interacting with the supported energy meter backends. The meter API functions can be used to configure the energy meter, send commands to the energy meter, poll for energy usage metrics, and receive responses from the energy meter.

For detailed information on how the meter API functions, please refer to the [Meter API Guide](./meter_api_guide.md) documentation.

The meter API directory structure falls under the `energy_collector` directory and is as follows:

```text
energy_collector/
|-- _meter_interfaces/
|   |-- include/
|   |   |-- meter_api.h
|   |   |-- <meter>.h
|   |-- src/
|       |-- meter_api.c
|       |-- <meter>.c
```

| **Path**                                                 | **Description**                                                                                                  |
|----------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| `energy_collector/`                                      | Root directory for the energy collector tool.                                                                    |
| `energy_collector/_meter_interfaces/`                    | Contains the generic meter API and all meter-specific backend implementations.                                   |
| `energy_collector/_meter_interfaces/include/`            | Contains public headers for the meter API and supported meter backends.                                          |
| `energy_collector/_meter_interfaces/include/meter_api.h` | Declares the generic meter API, shared data structures, and supported `MeterType` values.                        |
| `energy_collector/_meter_interfaces/include/<meter>.h`   | Declares the meter-specific device structures, constants, and backend function prototypes for a supported meter. |
| `energy_collector/_meter_interfaces/src/`                | Contains the meter API implementation and meter-specific backend source files.                                   |
| `energy_collector/_meter_interfaces/src/meter_api.c`     | Implements the generic meter API functions and device specific calls to the selected backend.                    |
| `energy_collector/_meter_interfaces/src/<meter>.c`       | Implements the meter-specific backend logic, such as connection setup, command sending, polling, and cleanup.    |

## Required Backend Functions for New Energy Meters

### Overview of Required Functions
When integrating a new energy meter into the PQC-LEO energy collector tool, there are several backend equivalent functions that should be implemented to ensure proper interaction with the energy meter. These functions are specific to the energy meter backend and should be named using a consistent prefix based on the name of the energy meter being added.

The generic meter API functions are already implemented in `meter_api.c`. The new meter backend should implement meter-specific versions of the main functions present in the generic meter API. For example, the backend functions could be named as follows for a new energy meter called `ExampleMeter`:

```c
examplemeter_init()
examplemeter_poll()
examplemeter_close()
examplemeter_send_cmd()
```

These backend functions are separated into two categories: core functions and secondary functions. The core functions are required for all energy meter backends, while secondary support is optional depending on meter capabilities.

| **Backend function**      | **Category** | **Purpose**                                                                                                  |
|---------------------------|--------------|--------------------------------------------------------------------------------------------------------------|
| `[meter_name]_init()`     | Core         | Used to initialise the connection to the energy meter and perform any necessary setup or configuration.      |
| `[meter_name]_poll()`     | Core         | Used to poll the energy meter for the current energy usage metrics and return the results.                   |
| `[meter_name]_close()`    | Core         | Used to close the connection to the energy meter and perform any necessary cleanup or resource deallocation. |
| `[meter_name]_send_cmd()` | Secondary    | Used to send a command to the energy meter if the meter supports command-based interaction.                  |

When implementing a new energy meter backend, it is important to ensure that the meter-specific functions follow the expected behaviour of the generic meter API functions. This ensures that the backend can be used by the energy collector tool in the same way as the other supported energy meters. The public API function workflows and expected return values are documented in the [Meter API Guide](./meter_api_guide.md).

If the energy meter supports command interaction, it is recommended to implement the secondary command function to provide additional flexibility for interacting with the energy meter. However, this is not crucial as the test orchestration scripts primarily rely on the core functions for collecting energy usage metrics. The source implementations will be defined in the relevant header and source files, please refer to the [Adding Energy Meter Backend Files](#adding-energy-meter-backend-files) section for further information. If command sending is not supported, **a relevant error handling mechanism should be implemented**. In that case, return a consistent non-zero "not supported" style error code so the caller can detect unsupported command flow without treating it as a polling failure.

## Adding Energy Meter Backend Files
When adding a new energy meter backend, the backend should be split into a header file and a source file. The header file should contain the meter-specific data structures, constants, and function prototypes. The source file should contain the implementation of the meter-specific functions that are used to interact with the energy meter.

For a new energy meter called `ExampleMeter`, the files should be added in the following locations:

```
energy_collector/
|-- _meter_interfaces/
|   |-- include/
|   |   |-- examplemeter.h
|   |-- src/
|       |-- examplemeter.c
```

The backend header file should contain a device structure that stores any state required to communicate with the energy meter. This can include serial port handles, USB handles, network socket details, vendor library contexts, cryptographic contexts, or any other state required by the energy meter device.

For example:

```c
typedef struct {
    void *connection;
    int baudrate;
} ExampleMeterDevice;
```

The backend header file should also contain any meter-specific structures that are needed to temporarily store data before it is copied into the generic meter API structures. If the energy meter reports additional fields that are not part of the `MeterReading` data structure, those fields can still be stored in the backend-specific polling structure. They can then be ignored by the generic API mapping if they are not currently required by the energy collector tool.

The backend source file should contain the device-specific protocol handling for the energy meter. This includes packet parsing, command formatting, response validation, unit conversion, and device-specific error handling. The generic `meter_api.c` file should only be used to call the backend functions and map the returned data into the generic meter API structures.

## Mapping Backend Readings to the Generic MeterReading Structure
The `MeterReading` data structure is the common structure used by the energy collector tool when storing live readings from an energy meter. Each new backend should map the meter-specific readings into this structure through the relevant backend functions in `meter_api.c`.

The current `MeterReading` structure supports the following fields:

| **Field**     | **Expected value**                                                |
|---------------|-------------------------------------------------------------------|
| `name`        | Energy meter name or model string.                                |
| `version`     | Energy meter firmware or version string.                          |
| `serial_num`  | Energy meter serial number string.                                |
| `sample_runs` | Number of samples or completed sample runs reported by the meter. |
| `voltage`     | Current voltage reading.                                          |
| `current`     | Current current reading.                                          |
| `power`       | Current power reading.                                            |
| `resistance`  | Current resistance reading, if provided by the meter.             |
| `temperature` | Current temperature reading, if provided by the meter.            |
| `d_plus`      | D+ line value, if provided by the meter.                          |
| `d_minus`     | D- line value, if provided by the meter.                          |
| `mAh`         | Accumulated mAh value, if provided by the meter.                  |
| `mWh`         | Accumulated mWh value, if provided by the meter.                  |

Not all energy meters will provide every field in the generic `MeterReading` structure. If a value is not supported by the energy meter, the backend mapping should set the field to `0` rather than leaving it uninitialised. This ensures that the collector tool does not write undefined values to the results files.

Any required unit conversion should also be handled before the data is copied into the `MeterReading` structure. For example, if the energy meter reports voltage in millivolts, the backend should convert it into volts before it is stored in the generic structure.

## Registering the New Energy Meter Type
After the backend files have been created, the new energy meter needs to be registered with the generic meter API. This is done in `meter_api.h` by including the backend header file and adding a new `MeterType` entry.

For example:

```c
#include "tc66c.h"
#include "examplemeter.h"
```

The `MeterType` enum should then be updated to include the new meter type:

```c
typedef enum {
    METER_TYPE_UNKNOWN = 0,
    METER_TYPE_TC66C,
    METER_TYPE_EXAMPLEMETER
} MeterType;
```

The `METER_TYPE_UNKNOWN` value should remain as `0`, and new meter types should be added after the existing supported meter types. This ensures that the existing meter type values are not changed when new backends are added.

Finally, to allow the meter type to be accessed in the collector program, the array containing the supported meter names should be updated in `collector.h` (located at `energy_collector/include/collector.h`) to include the new meter type:

For example:
```c
static const MeterTypeOption supported_meter_types[] = {
    {1, "TC66C", METER_TYPE_TC66C},
    {2, "ExampleMeter", METER_TYPE_EXAMPLEMETER}
};
```

Where each entry follows this data structure defined in `collector.h`:

```c
typedef struct {
    int option_number;
    const char *name;
    MeterType type;
} MeterTypeOption;
```

This allows the collector program to present the new energy meter as a selectable option during setup and pass the selected `MeterType` value into the generic meter API functions.

## Adding the Generic API Calling Logic
Once the new `MeterType` value has been added, the generic API implementation in `meter_api.c` needs to be updated so that the public meter API functions call the new backend functions. This is done by adding a new `case` statement for the new meter type in the relevant `switch` statements.

The following functions contain `switch` statements that should be updated for the new meter type:

| **Generic API function** | **Backend function that should be called** |
|--------------------------|--------------------------------------------|
| `meter_init()`           | `[meter_name]_init()`                      |
| `meter_send_cmd()`       | `[meter_name]_send_cmd()`                  |
| `meter_poll()`           | `[meter_name]_poll()`                      |
| `meter_close()`          | `[meter_name]_close()`                     |

The `meter_init()` function should allocate the meter-specific device structure, set the `device_instance` pointer, set the meter type, and then call the backend initialisation function.

The `meter_poll()` function should call the backend polling function and then copy the backend-specific polling data into the generic `MeterReading` structure.

The `meter_close()` function should call the backend close function, free the allocated backend device structure, set `device->device_instance` to `NULL`, and reset `device->type` to `METER_TYPE_UNKNOWN`.

If the energy meter does not support command sending, the relevant generic API function should return a relevant error code and not call the backend function. Ideally this is done in a way which does not interrupt the normal operation of the collector tool, as this is a secondary function that is not required for energy usage collection.

## Build Behaviour for New Meter Backends
The energy collector makefile automatically builds C source files that are placed in the `_meter_interfaces/src/` directory. This means that a new backend source file such as `examplemeter.c` will be compiled and included in `libmeter_api.a` without needing to manually add the source file to the makefile.

The backend will still require a makefile update if it depends on additional external libraries, include directories, or linker flags. For example, a meter backend that depends on a vendor SDK may require an additional include path in `CFLAGS` and an additional library in `LDLIBS`.

After adding a backend, the energy collector tool can be rebuilt from the `tools/energy_collector` directory:

```bash
make clean
make
```

## Testing the New Energy Meter Integration
After the backend has been implemented and registered, the integration should be tested before the energy meter is added to the supported meter list.

The following checks should be performed:

| **Test area**       | **Expected result**                                                                                 |
|---------------------|-----------------------------------------------------------------------------------------------------|
| Build test          | The energy collector tools build successfully with the new backend included.                        |
| Initialisation test | The new meter can be initialised through `meter_init()`.                                            |
| Polling test        | The meter returns live readings through `meter_poll()`.                                             |
| Data mapping test   | The values copied into `MeterReading` use the expected units and unsupported fields are set to `0`. |
| Command test        | `meter_send_cmd()` works if the meter supports commands.                                            |
| Close test          | `meter_close()` releases the backend resources and resets the generic meter device state.           |
| Collector test      | The `collector` program can use the new meter during a normal energy collection run.                |

If possible, the polling results should be checked against the energy meter display or another known measurement source. This helps confirm that the backend is applying the correct unit conversions and parsing the correct response fields.

## Updating Energy Meter Documentation
Once the new backend has been implemented and tested, the project documentation should be updated so that users know the energy meter is supported and how to use it.

The supported meter list should be updated in:

```
docs/energy_meter_guides/energy_meter_support.md
```

The new energy meter should also have its own usage documentation under the supported meters directory. For example:

```
docs/energy_meter_guides/supported_meters/ExampleMeter/examplemeter_meter_usage_guide.md
```

The usage guide should describe how to connect and configure the meter for energy usage testing.
