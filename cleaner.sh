#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# Utility script for cleaning up project files produced during PQC benchmarking.
# Provides options to uninstall the OQS-Provider libraries, clear old benchmarking results and generated TLS keys, or perform both actions.
# Uninstalling will remove the Liboqs, OQS-Provider, and OpenSSL 3.5.0 installations from the system.
# Clearing results will remove test outputs and key material under the test-data directory.

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for setting up the global environment variables for the test suite. This includes determining the root directory 
    # by tracing the script's location, and configuring paths for libraries, test data, and temporary files.

    # Determine the directory that the script is being executed from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the project's root directory
    current_dir="$script_dir"

    # Continue moving up the directory tree until the .pqc_eval_dir_marker.tmp file is found
    while true; do

        # Check if the .pqc_eval_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_eval_dir_marker.tmp" ]; then
            root_dir="$current_dir"  # Set root_dir to the directory, not including the file name
            break
        fi

        # Move up a directory and store the new path
        current_dir=$(dirname "$current_dir")

        # If the system's root directory is reached and the file is not found, exit the script
        if [ "$current_dir" == "/" ]; then
            echo -e "Root directory path file not present, please ensure the path is correct and try again."
            exit 1
        fi

    done

    # Declare the main directory path variables based on the project's root dir
    dependency_dir="$root_dir/dependency_libs"
    libs_dir="$root_dir/lib"
    tmp_dir="$root_dir/tmp"
    test_data_dir="$root_dir/test_data"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_3.5.0"
    liboqs_path="$libs_dir/liboqs"
    oqs_provider_path="$libs_dir/oqs_provider"

    # Declaring the global source-code directory path variables
    liboqs_source="$tmp_dir/liboqs_source"
    oqs_provider_source="$tmp_dir/oqs_provider_source"
    openssl_source="$tmp_dir/openssl_3.5.0"

    # Declaring the global test-data directory path variables
    test_data_results="$test_data_dir/results"
    test_data_up_results="$test_data_dir/up_results"
    test_data_keys="$test_data_dir/keys"
    test_data_alg_lists_dir="$test_data_dir/alg_lists"

}

#------------------------------------------------------------------------------
function select_uninstall_mode() {
    # Function for selecting the uninstall option for the currently installed dependency libraries. 
    # The function will also remove the generated algorithms lists from the test-data directory
    # depending on the user's uninstall choice.

    # Output the current task to the terminal
    echo -e "\n########################"
    echo "Uninstalling Libraries"
    echo -e "########################"

    # Prompt the user for their choice until a valid response is given
    while true; do

        # Output the choices for uninstalling the libraries
        echo -e "\nPlease Select one of the following uninstall options"
        echo "1 - Uninstall Liboqs Library Only"
        echo "2 - Uninstall OQS-Provider Library only"
        echo "3 - Uninstall OpenSSL 3.5.0 Only"
        echo "4 - Uninstall all Libraries"
        echo "5 - Exit Setup"

        # Read in the user's response
        read -p "Enter your choice (1-5): " user_opt

        # Determine the action based on the user's response
        case "$user_opt" in 

            1)
                # Uninstall Liboqs only
                rm -rf "$liboqs_path"
                rm "$test_data_alg_lists_dir/kem_algs.txt"
                rm "$test_data_alg_lists_dir/sig_algs.txt"
                echo -e "\nLiboqs Uninstalled"
                break;;
            
            2)
                # Uninstal OQS-Provider only
                rm -rf "$oqs_provider_path"
                rm $test_data_alg_lists_dir/*tls*.txt
                echo -e "\nOQS-Provider Uninstalled"
                break;;

            3)
                # Uninstall OpenSSL 3.5.0 only
                rm -rf "$openssl_path"
                echo -e "\nOpenSSL 3.5.0 Uninstalled"
                break;;

            4)
                # Uninstall all dependency libraries
                rm -rf "$libs_dir" && rm -rf "$tmp_dir" && rm -rf "$dependency_dir"
                rm -rf "$root_dir/.pqc_eval_dir_marker.tmp"
                rm -rf "$test_data_alg_lists_dir"
                echo -e "\nAll Libraries Uninstalled"
                break;;

            5)

                # Exit the script
                echo "Exiting Uninstall Script!"
                exit 1
                ;;

            *)

                # Output to the user that the input is invalid and prompt again
                echo -e "\nInvalid option, please select valid option value (1-4)\n"
                ;;
            
        esac

    done

}

#------------------------------------------------------------------------------
function remove_old_results() {
    # Function for removing old test results and generated keys directories from the test-data directory

    # Output the current task to the terminal
    echo -e "\n###############################"
    echo "Clearing Results and TLS Keys"
    echo -e "\n###############################\n"

    # Verify the user definitely wants to remove all results and keys
    while true; do 

        read -p "Are you sure you want to remove all stored results and generated keys? This cannot be reversed if you do not have backup copies! (y/n): " user_input

        # Check if user wants to remove all results and keys
        if [ "$user_input" == "y" ]; then
            break
        elif [ "$user_input" == "n" ]; then
            echo "Exiting Cleaning Script!"
            exit 1
        else
            echo -e "\nInvalid input, please enter 'y' or 'n'\n"
        fi

    done

    # Remove all relevant directories
    rm -rf "$test_data_results"
    rm -rf "$test_data_up_results"
    rm -rf "$test_data_keys"
    rm -rf "$tmp_dir/*"
    echo -e "\nAll results and generated keys cleared\n"

}

#------------------------------------------------------------------------------
function main() {
    # Main function for controlling the uninstall utility script

    # Setup the base environment for the utility script
    setup_base_env
    
    # Output the welcome message to the terminal
    echo "#################################"
    echo "Project Cleaner Utility Script"
    echo "#################################"

    # Determine what clearing action the user would like to perform
    while true; do

        # Output the uninstall options to the user
        echo -e "\nPlease select what clearing action you would like to perform"
        echo "1 - Uninstall Libraries Only"
        echo "2 - Clear old test results and generated TLS Keys Only"
        echo "3 - Uninstall libraries and clear old test results/generated TLS keys"
        echo "4 - Exit Cleaning Script"

        # Read in the user's response
        read -p "Enter your choice (1-4): " user_opt

        # Determine the action based on the user's response
        case "$user_opt" in 

            1)
                # Uninstall dependency libraries only
                echo -e "\nOption 1 Selected: Uninstall Libraries Only"
                select_uninstall_mode
                break;;

            2)
                # Clear old test results and generated keys only
                echo -e "\nOption 2 Selected: Clear Old Test Results and Generated TLS Keys"
                remove_old_results
                break;;

            3)
                # Uninstall both OQS libraries and clear old test results and generated keys
                echo -e "\nOption 3 Selected: Uninstall Libraries and Clear Old Test Results/Generated TLS Keys"
                select_uninstall_mode
                remove_old_results
                break;;

            4)

                # Exit the script
                echo "Exiting Uninstall Script!"
                exit 1
                ;;

            *)

                # Output to the user that the input is invalid and prompt again
                echo -e "\nInvalid option, please select valid option value (1-4)\n"
                ;;
            
        esac
    
    done
    
}
main