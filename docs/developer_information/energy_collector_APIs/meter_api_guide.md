# Energy Collector Meter API Guide <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides a developer reference for the meter API included within the PQC-LEO energy collector tools. The API provides a unified interface for interacting with supported energy meters, allowing applications to initialise a meter, send device commands, collect current energy usage metrics, and release the meter connection without depending directly on a specific meter backend.

The guide describes the data structures and functions included within the meter API. It also provides usage examples, from configuration and initialisation through polling to closing the connection. For the list of compatible devices, refer to [Energy Meter Support](../../energy_meter_guides/energy_meter_support.md); for instructions on building and running the energy collector tools, refer to the [Energy Collector Tool Usage Guide](../../project_tools_guides/energy_collector_usage_guide.md).

### Contents <!-- omit from toc -->
- [API Description](#api-description)
- [Meter API Data Structures](#meter-api-data-structures)
  - [MeterType Data Structure](#metertype-data-structure)
  - [MeterReading Data Structure](#meterreading-data-structure)
  - [MeterDevice Data Structure](#meterdevice-data-structure)
- [Meter API Functions](#meter-api-functions)
  - [meter\_init() Function](#meter_init-function)
  - [meter\_send\_cmd() Function](#meter_send_cmd-function)
  - [meter\_poll() Function](#meter_poll-function)
  - [meter\_close() Function](#meter_close-function)
- [Meter API Function Usage](#meter-api-function-usage)
  - [Configure and Initialise the Energy Meter](#configure-and-initialise-the-energy-meter)
  - [Sending a Command to the Energy Meter](#sending-a-command-to-the-energy-meter)
  - [Polling for Readings from the Energy Meter](#polling-for-readings-from-the-energy-meter)
  - [Closing the Connection with the Energy Meter](#closing-the-connection-with-the-energy-meter)

## API Description
The meter API provides an abstraction layer for interacting with supported energy meters and coordinating the collection of energy usage metrics. It defines a set of unified functions for the energy meter backends used by the energy usage collector tool. These functions can be used to configure the meter, send commands, poll for energy usage metrics, and receive responses.

Based on the parameters passed to the meter API functions, the API determines which energy meter backend to use and calls the appropriate backend functions to perform the requested operation. The list of supported backends is provided in the [Energy Meter Support](../../energy_meter_guides/energy_meter_support.md) document. Information on integrating new meters into the PQC-LEO energy usage collector tool is provided in the [Integrating New Energy Meters](./integrating_new_energy_meters.md) document.

The following library file is produced when the energy collector tools are built, which contains the meter API functions:

- `libmeter_api.a`

It consists of the following header file that contains the function prototypes for the meter API functions:

- meter_api.h

The header file imports the supported energy meter backend header files, which contain the function prototypes used by the meter API to perform the requested operations on supported energy meters.

## Meter API Data Structures
The following data structures are used by the meter API functions for configuring the energy meter, sending commands, and receiving responses from the energy meter. The data structures are defined in the `meter_api.h` header file.

- MeterType
- MeterReading
- MeterDevice

In addition to the data structures described above, the `meter_api.h` header file includes several definitions that set the maximum sizes of selected data structure elements. These definitions are listed below:

- `METER_NAME_MAX_LEN` - Defines the maximum length of the name of the energy meter.

- `METER_VERSION_MAX_LEN` - Defines the maximum length of the version number of the energy meter.

- `METER_SERIAL_MAX_LEN` - Defines the maximum length of the serial number of the energy meter.

### MeterType Data Structure
The `MeterType` data structure is used to specify the type of energy meter that is being used. It is defined as an enumeration in the `meter_api.h` header file. When integrating new energy meters, the `MeterType` enumeration will need to be updated to include the new energy meter type. The current version of the `MeterType` enumeration is defined as follows:

```c
typedef enum {
    METER_TYPE_UNKNOWN = 0,
    METER_TYPE_TC66C
} MeterType;
```

Based on the passed `MeterType` value, the appropriate backend functions are called in the meter API to perform the requested operations on the specified energy meter.

### MeterReading Data Structure
The `MeterReading` data structure is used to store the energy usage metrics that are collected from the energy meter. It is defined as a structure in the `meter_api.h` header file. It is used to store various energy usage metrics, such as voltage, current, power, energy consumption, and temperature. The `MeterReading` structure is defined as follows in the `meter_api.h` header file:

```c
typedef struct {
    char name[METER_NAME_MAX_LEN];
    char version[METER_VERSION_MAX_LEN];
    char serial_num[METER_SERIAL_MAX_LEN];
    unsigned int sample_runs;
    float voltage;
    float current;
    float power;
    float resistance;
    float temperature;
    float d_plus;
    float d_minus;
    unsigned int mAh;
    unsigned int mWh;
} MeterReading;
```

- `char name[METER_NAME_MAX_LEN]` - A string that stores the name of the energy meter.
- `char version[METER_VERSION_MAX_LEN]` - A string that stores the firmware/version of the energy meter.
- `char serial_num[METER_SERIAL_MAX_LEN]` - A string that stores the serial number of the energy meter.
- `unsigned int sample_runs` - The number of completed meter sample runs.
- `float voltage` - The current voltage reading.
- `float current` - The current current reading.
- `float power` - The current power reading.
- `float resistance` - The current resistance reading.
- `float temperature` - The current temperature reading.
- `float d_plus` - The D+ line metric reported by the meter.
- `float d_minus` - The D- line metric reported by the meter.
- `unsigned int mAh` - Accumulated mAh reading.
- `unsigned int mWh` - Accumulated mWh reading.

This data structure is passed to the meter API functions when collecting energy usage metrics from the energy meter. The meter API functions will populate the fields of the `MeterReading` structure with the collected energy usage metrics from the energy meter. They can then be accessed after the meter has been polled where the data can be printed or stored in a file for later analysis.

If integrating new energy meters and the device does not provide certain expected values, the corresponding fields in the `MeterReading` structure should be set to a default value of 0.

### MeterDevice Data Structure
The `MeterDevice` data structure is used to store the meter type and the initialised device instance pointer for API calls. The `MeterDevice` structure is defined as follows in the `meter_api.h` header file:

```c
typedef struct {
    MeterType type;
    void *device_instance;
} MeterDevice;
```

- `MeterType type` - The type of energy meter that is being used.
- `void *device_instance` - A pointer to the initialised device instance for the specified energy meter type. This pointer is used by the meter API functions to interact with the energy meter device.

## Meter API Functions
The following meter API functions are provided in the `meter_api.h` header file. These functions can be used to configure the energy meter, send commands to it, poll for energy usage metrics, and receive responses. They provide a unified interface for interacting with the supported energy meters, regardless of the specific backend being used:

- meter_init()
- meter_send_cmd()
- meter_poll()
- meter_close()

### meter_init() Function
Function for initialising an energy meter device. It configures the device based on its type and the provided serial port name. It will check the device type and initialise the appropriate device instance based on what is currently supported. New device instances can be added here as needed.

```c
int meter_init(MeterDevice *device, MeterType type, const char *serial_port_name);
```

Parameters:
- `MeterDevice *device` - Pointer to the `MeterDevice` structure that will be populated with the initialised device instance and meter type.
- `MeterType type` - The type of energy meter to initialise. This should be one of the values from the `MeterType` enumeration.
- `const char *serial_port_name` - The serial port name that the energy meter is connected to. This should be a valid serial port name for the system.

Returns:
- `0` on success
- `-1` on failure

### meter_send_cmd() Function
Function for sending a command to an energy meter device. It will check the device type and call the relevant command sending function. The command message is sent to the active meter device, and the function will return a status code indicating the success or failure of the operation.

```c
int meter_send_cmd(MeterDevice *device, const char *message);
```

Parameters:
- `MeterDevice *device` - Pointer to the `MeterDevice` structure that contains the initialised device instance and meter type.
- `const char *message` - Null-terminated command payload to be sent to the energy meter device.

Returns:
- `0` on success
- `-1` on failure

### meter_poll() Function
Function for polling an energy meter device for readings. It will check the device type and call the relevant polling function to retrieve the current readings from the device. The retrieved data is stored in the provided MeterReading struct.

```c
int meter_poll(MeterDevice *device, MeterReading *reading);
```

Parameters:
- `MeterDevice *device` - Pointer to the `MeterDevice` structure that contains the initialised device instance and meter type.
- `MeterReading *reading` - Pointer to the `MeterReading` structure where the retrieved readings will be stored.

Returns:
- `0` on success
- `-1` on failure

### meter_close() Function
Function for closing a connection instance with an energy meter device. It will check the device type and call the relevant closing function to release the device resources.

```c
int meter_close(MeterDevice *device);
```

Parameters:
- `MeterDevice *device` - Pointer to the `MeterDevice` structure that contains the initialised device instance and meter type.

Returns:
- `0` on success
- `-1` on failure

## Meter API Function Usage
The meter API functions can be used to interact with the supported energy meters in a unified manner. The following is an example of how to use the meter API functions to initialise an energy meter, send a command, poll for readings, and close the connection with the energy meter.

### Configure and Initialise the Energy Meter
The first step is to configure and initialise the energy meter device. This is done by creating a `MeterDevice` structure and calling the `meter_init()` function with the appropriate parameters.

```c
#include "meter_api.h"

// Create a MeterDevice structure
MeterDevice device;

// Define the serial port name for the energy meter and the type of energy meter being used
const char *serial_port_name = "/dev/ttyUSB0";

// Initialise the energy meter device
int ret = meter_init(&device, METER_TYPE_TC66C, serial_port_name);
```

### Sending a Command to the Energy Meter
Once the energy meter is initialised, you can send commands to the energy meter using the `meter_send_cmd()` function. For example, to switch the TC66C display to the next page:

```c
#include "meter_api.h"

// Define the command to be sent to the energy meter
const char *command = "nextp";

// Send the command to the energy meter
int ret = meter_send_cmd(&device, command);
```

### Polling for Readings from the Energy Meter
You can poll the energy meter for readings using the `meter_poll()` function. The retrieved readings will be stored in a `MeterReading` structure.

```c
#include "meter_api.h"

// Define an instance of the MeterReading structure to hold the retrieved readings
MeterReading meter_reading;

// Poll the energy meter for readings
int ret = meter_poll(&device, &meter_reading);

// Print the retrieved readings
printf("Voltage: %.2f V | Current: %.2f A | Power: %.2f W | Temp: %.1f°C\n", meter_reading.voltage, meter_reading.current, meter_reading.power, meter_reading.temperature);
```

### Closing the Connection with the Energy Meter
Once you are done interacting with the energy meter, you should close the connection using the `meter_close()` function to release the device resources.

```c
#include "meter_api.h"

// Close the connection with the energy meter
int ret = meter_close(&device);
```
