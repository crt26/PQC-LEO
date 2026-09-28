"""
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

Utility script for listing available serial ports using pyserial, prompting the user to choose one, and printing only 
the selected device path to stdout. All interactive prompts and menu output are written to stderr so that calling
shell scripts can capture the selected port path from stdout without any additional output.

This utility script is intended to be called by automated energy usage test 
scripts when the user wishes to use serial communication for control signalling.

"""
import sys
from serial.tools import list_ports

#------------------------------------------------------------------------------------------------------------------------------
def get_serial_ports():
    """Helper function to return a sorted list of available serial ports on the system using pyserial."""

    # Attempt to get the list of available serial ports using pyserial
    try:

        # Get the list of available serial ports using pyserial
        ports = sorted(list_ports.comports(), key=lambda port: port.device)

        # Ensure that ports were found before returning the list
        if not ports:
            raise RuntimeError("No serial ports found.")

        return ports
        
    except Exception as error_message:
        print(f"[ERROR] - {error_message}", file=sys.stderr)
        sys.exit(1)

#------------------------------------------------------------------------------------------------------------------------------
def get_user_choice(serial_ports):
    """Helper function to prompt the user for a port selection and return the selected path."""

    # Output the available serial ports to the user
    print("Available serial (com) ports on this system:", file=sys.stderr)
    for index, port in enumerate(serial_ports, start=1):
        print(f"{index}) {port.device}", file=sys.stderr)

    # Prompt the user to select a serial port until a valid selection is made
    while True:

        # Prompt the user for a selection and store the input
        print("Please enter com port to use: ", end="", file=sys.stderr)
        user_input = input().strip()

        # Ensure input is numeric before converting to integer
        if not user_input.isdigit():
            print("[WARNING] - Invalid selection, please choose a number from the list.\n", file=sys.stderr)
            continue

        selected_num = int(user_input)

        # Validate the user input to ensure it is a valid selection
        if selected_num >= 1 and selected_num <= len(serial_ports):

            # If the selection is valid, return the selected serial port
            selected_port = serial_ports[selected_num - 1].device
            return selected_port
        
        else:
            print("[WARNING] - Invalid selection, please choose a number from the list.\n", file=sys.stderr)
            continue

#------------------------------------------------------------------------------------------------------------------------------
def main():

    # Get the available serial ports on the system
    available_ports = get_serial_ports()

    # Prompt the user to select a serial port from the available options
    selected_port = get_user_choice(available_ports)

    # Output only the selected serial port path to stdout so shell callers can capture it
    print(selected_port)

#------------------------------------------------------------------------------------------------------------------------------
"""Main boiler plate"""
if __name__ == "__main__":
    main()