# Supported Energy Meters <!-- omit from toc -->

## Overview <!-- omit from toc -->
This document provides information related to the energy meters that are currently supported by PQC-LEO for energy usage testing. This document provides an overview of the currently supported energy meters and links to detailed documentation and usage guides for each of the supported energy meters. This document also provides a brief guide on how additional energy meters can be integrated into the PQC-LEO energy usage testing tooling and links to more detailed developer documentation for integrating support for additional energy meters.

### Contents <!-- omit from toc -->
- [Supported Energy Meters](#supported-energy-meters)
- [Integrating Support for Additional Energy Meters](#integrating-support-for-additional-energy-meters)

## Supported Energy Meters
PQC-LEO currently supports energy data collection using the following energy meters:

| **Energy Meter** | **Description**                                                                                                                                              | **Documentation**                                                        |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| TC66C            | The TC66C is a small USB-C multimeter device that can be used to measure various electrical metrics such as voltage, current, power, and energy consumption. | [TC66C Usage Guide](./supported_meters/TC66C/tc66c_meter_usage_guide.md) |

## Integrating Support for Additional Energy Meters
If you have an energy meter that you would like to use with the PQC-LEO energy usage testing tooling that is not currently supported, you can integrate support for the energy meter into PQC-LEO by following the general process outlined in the [Energy Meter Integration Guide](../developer_information/energy_collector_APIs/integrating_new_energy_meters.md).
