#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Utility script for configuring and restoring the testing machine system state. It accepts one
# command line argument to set the default state, set custom state values, or restore the original
# configuration. Supports CPU governor selection, CPU core selection, and fan control settings for
# the test environment. This script is intended to be used in conjunction with the the energy 
# usage testing scripts to ensure a consistent and controlled testing environment for accurate energy 
# usage measurements. Based on the detected command line arguments, the script will either set the system state 
# to a default configuration optimised for testing, or it will prompt the user to input custom values for the system 
# state configuration.

# TODO - Improve the scripts ability to automatically determine which CPU core to use for testing
# TODO - Implment fan control functionality

# Define the global variables
configure_type=""
configure_value_type=""

# Define the default values for the system states
cpu_governor_mode="performance"
fan_mode="max" # options (max|custom)
cpu_core="0"

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the supported options and their usage to the user
    echo "Usage: system_state_configurer.sh [options]"
    echo "Options:"
    echo "--custom   Set custom system state values. Prompts for CPU governor, CPU core, and fan settings"
    echo "--default  Set the system state to the default configuration optimised for testing."
    echo "--help     Display the help message."

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing the command line arguments passed to the script. Based on the detected arguments, the function will 
    # set the relevant global flags that are used throughout the setup process.

    # Check if the help flag is passed at any position in the command line arguments
    if [[ "$*" =~ --help ]]; then
        output_help
        exit 0
    fi

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        case "$1" in

            --set-default)

                # Ensure that configure type is not already set
                if [[ -n "$configure_type" ]]; then
                    echo "[ERROR] - Multiple configuration types detected. Please specify only one configuration type per execution."
                    exit 1
                fi

                # Set the configuration type to default
                configure_type="set"
                configure_value_type="default"
                shift
                ;;

            --set-custom)

                configure_type="set"
                configure_value_type="custom"
                shift
                ;;


            --restore)
                configure_type="restore"
                shift
                ;;

            *)
                echo "[ERROR] - Invalid argument detected: $1. Please verify the function call and try again."
                output_help
                exit 1
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function cpu_core_detector() {
    # Function for determining which CPU core to run the tests on. By default, it will select the second core if more than one is 
    # available to avoid running tests on the core more likely to be used by system processes, but it will prompt the user to select 
    # a core if the custom configuration option is selected.

    # TO-DO improve to automatically determine the best CPU core to use based on the system topology

    # Store the number of available CPU Cores
    local n
    n=$(nproc)

    # Utilise the second core for testing if more than one is available to avoid running tests on core more used by system processes
    if [[ "$n" -le 1 ]]; then
        target_cpu_core="0"
    else
        target_cpu_core="1"
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_custom_state_values() {
    # Function for prompting the user to input custom values for the system state configurations. The function will prompt the
    # user for the desired CPU governor mode, the CPU core to run the tests on, and the desired fan control mode. The function will
    # validate the user input and set the relevant global variables based on the detected values.

    # Output the current task to the terminal
    echo "Configuring target CPU governor state"

    # Define the valid options for the CPU governor and prompt the user to select one of them
    local valid_governors=("performance" "powersave" "userspace" "ondemand" "conservative" "schedutil")

    # Prompt the user to select a CPU governor mode until a valid selection is made
    while true; do

        # Output the available options for CPU governor modes to the user
        echo "Please select a CPU governor mode from the following options:"

        option_number=1
        for gov in "${valid_governors[@]}"; do
            echo "$option_number) $gov"
            ((option_number++))
        done

        # Prompt the user for their selection
        read -p "Enter the CPU governor mode (1-${#valid_governors[@]}): " cpu_governor_choice

        # Validate the user's selection and set the cpu_governor_mode variable accordingly
        if [[ "$cpu_governor_choice" -ge 1 && "$cpu_governor_choice" -le ${#valid_governors[@]} ]]; then
            cpu_governor_mode="${valid_governors[cpu_governor_choice-1]}"
            break
        else
            echo "[WARNING] - Invalid selection for CPU governor mode, please enter a valid option number"
        fi
    
    done

    # Determine the number of cores available on the system, including virtual threads
    local core_count=$(nproc)
    echo "The system has the a total of $core_count CPU cores (including virtual threads)."

    # Prompt the user for a CPU core to run the tests on until a valid value is selected
    while true; do

        # Prompt the user to enter a CPU core number to run the tests
        read -p "Please enter the CPU core number to run the tests on (0-$(($core_count - 1))): " cpu_core_choice

        # Ensure that the entered value is a valid integer 
        if ! [[ "$cpu_core_choice" =~ ^[0-9]+$ ]]; then
            echo "[WARNING] - Invalid input, please enter a valid integer for the CPU core number."
            continue
        fi

        # Ensure that the entered core number is within the valid range of available cores on the system
        if [[ "$cpu_core_choice" -ge 0 && "$cpu_core_choice" -lt "$core_count" ]]; then
            target_cpu_core="$cpu_core_choice"
            break
        else
            echo "[WARNING] - Invalid CPU core number entered, please enter a valid integer between 0 and $(($core_count - 1))"
        fi

    done

    # Prompt the user for the desired fan configuration until a valid setting is set
    while true; do

        # Prompt the user for the desired fan mode
        echo "Available fan speed targets:"
        echo "1) Max Speed"
        echo "2) Off"
        read -p "Please select the desired fan speed target (1-3): " user_fan_target

        # Ensure that the entered value is a valid integer
        if ! [[ "$user_fan_target" =~ ^[1-3]$ ]]; then
            echo -e "[WARNING] - Invalid input, please enter a valid integer for the fan speed target.\n"
            continue
        fi

        # Determine which fan mode was selected
        case "$user_fan_target" in
        
            1)
                # Set the fan mode to max speed
                fan_mode="max"
                break
                ;;

            2)
                # Set the fan mode to off
                fan_mode="off"
                break
                ;;

            *)
                echo -e "[WARNING] - Invalid selection for fan speed target, please enter a valid option number.\n"
                continue
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_cpu_freq() {
    # Function for configuring the CPU frequency scaling governor for the testing machine. The function takes in an argument to 
    # either set the governor to performance mode or restore it to the original setting. When setting to performance mode, 
    # the function saves the original governor setting to a temp file for later restoration.

    # Store the passed argument in a local variable and define the SUDO variable based on the current user's permissions
    local action="$1"
    local SUDO=""
    [[ $EUID -ne 0 ]] && SUDO="sudo"

    # Use a temporary file to preserve the current governor before changing it so it can be restored later
    local STATE_FILE="/tmp/.orig_cpu_governor"

    # Validate the requested governor mode when setting a new value
    local requested_governor="$cpu_governor_mode"

    # Determine which action to take based on the passed argument
    case "$action" in

        cpu_governor_set)

            # Store the current CPU governor setting once so the original state can be restored later
            if [[ ! -f "$STATE_FILE" ]]; then
                cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor > "$STATE_FILE"
            fi

            if [[ -z "$requested_governor" ]]; then
                echo "[ERROR] - No CPU governor mode was provided."
                exit 1
            fi

            # Ensure that there is a CPU governor file before proceeding
            if [[ ! -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]]; then
                echo "[ERROR] - No CPU governor file found, unable to set CPU frequency scaling governor."
                cpu_gov_set_fail=1
                return 1
            fi

            # Set the CPU frequency scaling governor to the requested mode for all CPUs
            echo "Setting CPU governor to $requested_governor..."
            for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
                echo "$requested_governor" | $SUDO tee "$cpu/cpufreq/scaling_governor" > /dev/null || cpu_gov_set_fail=1
            done

            if [[ "$cpu_gov_set_fail" -ne 0 ]]; then
                echo "[ERROR] - Failed to set one or more CPU governor values."
                return 1
            fi
            ;;

        cpu_governor_restore)

            # Restore the original CPU governor setting
            if [[ -f "$STATE_FILE" ]]; then
                local restore_fail=0

                # Read in the original governor setting from the state file
                local orig
                orig=$(cat "$STATE_FILE")

                # Restore the CPU governor to the original setting for all CPUs
                echo -e "\nRestoring CPU governor to $orig..."
                for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
                    echo "$orig" | $SUDO tee "$cpu/cpufreq/scaling_governor" > /dev/null || restore_fail=1
                done

                if [[ "$restore_fail" -ne 0 ]]; then
                    echo "[ERROR] - Failed to restore one or more CPU governor values."
                    return 1
                fi

                # Remove the temp state file after restoration
                rm -f "$STATE_FILE"

            else
                echo "[ERROR] - No saved governor state found!"
                return 1

            fi
            ;;

        *)

            # Output that an invalid argument was passed to the function and provide usage instructions
            echo "[ERROR] - Invalid argument passed to set_cpu_freq function, please verify the function call and try again."
            exit 1
            ;;

    esac

}

#-------------------------------------------------------------------------------------------------------------------------------
function sys_state_modifier_entrypoint() {
    # Main entry point for the system state modifier script. This function is responsible for orchestrating the execution of the 
    # script by first parsing the command line arguments and then calling the relevant helper functions to modify the system state 
    # based on the detected arguments.

    # Declare the system state configure function fail flags
    cpu_gov_set_fail=0
    fan_control_set_fail=0

    # Ensure that arguments have been passed to the script and parse them
    if [[ $# -gt 0 ]]; then
        parse_args "$@"
    else
        echo "[ERROR] - No arguments passed to configure-openssl-cnf.sh"
        output_help
        exit 1
    fi

    # if the configure type is set and the value type is custom, get the custom values from the user
    if [[ "$configure_type" == "set" && "$configure_value_type" == "custom" ]]; then
        get_custom_state_values
    fi

    # Run the system state modifications based on the detected configuration type and value type
    if [[ "$configure_type" == "set" ]]; then

        # Call the relevant system state configuration functions in set mode
        set_cpu_freq "cpu_governor_set"
        cpu_core_detector

        # If the any of the system state configuration functions failed, restore the original state for the function that did not fail if any
        if [[ "$cpu_gov_set_fail" -eq 1 ]]; then
            echo "[ERROR] - Failed to set CPU governor mode, attempting to restore the original CPU governor setting..."
            set_cpu_freq "cpu_governor_restore"
            exit 1
        
        elif [[ "$fan_control_set_fail" -eq 1 ]]; then
            echo "[ERROR] - Failed to set fan control mode, attempting to restore CPU governor setting..."
            set_cpu_freq "cpu_governor_restore"
            exit 1

        fi

        # Export the target_cpu_core value
        printf 'TARGET_CPU_CORE=%s\n' "$target_cpu_core"
        
        # TO-DO add fan control function call here when implemented

    elif [[ "$configure_type" == "restore" ]]; then
        set_cpu_freq "cpu_governor_restore"

        # TO-DO add fan control restoration function call here when implemented
    fi

}
sys_state_modifier_entrypoint "$@"