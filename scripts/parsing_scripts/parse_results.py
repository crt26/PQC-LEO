"""
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

Controller script for parsing PQC performance and energy testing results produced by the
computational and TLS test suites. Supports parsing of:

- Computational performance results
- TLS performance results
- Energy consumption results (computational energy, TLS handshake energy, TLS speed energy)

The script accepts parameters via command-line arguments or an interactive prompt, collects the
required test options (Machine-ID, number of runs, energy test type), invokes the appropriate
internal parser modules, and writes cleaned CSV outputs to the project's results directory.
Parsing is supported on Linux and relies on the original algorithm list files used during testing.
"""

#------------------------------------------------------------------------------------------------------------------------------
import os
import sys
import argparse
from internal_scripts.performance_data_parse import parse_comp_performance
from internal_scripts.tls_performance_data_parse import parse_tls_performance
from internal_scripts.energy_data_parse import parse_energy_data

#------------------------------------------------------------------------------------------------------------------------------
def handle_args():
    """ Function for handling command-line arguments for the script, validates them, and returns the parsed arguments. 
        Raises errors and exits if arguments are invalid. """
    
    # Define the argument parser and the valid options for the script
    parser = argparse.ArgumentParser(description="PQC-LEO Results Parsing Tool")
    parser.add_argument('--parse-mode', type=str, help='The parsing mode to be used (computational, tls, or energy)')
    parser.add_argument('--machine-id', type=int, help='The Machine-ID of the results to be parsed')
    parser.add_argument('--total-runs', type=int, help='The number of test runs to be parsed')
    parser.add_argument('--energy-test-type', type=int, help='The type of energy usage testing performed (1: PQC Computational, 2; TLS Handshake, 3: TLS Speed)')
    parser.add_argument("--replace-old-results", action="store_true", help="Replace old results for the passed Machine-ID if this flag is set")
    parser.add_argument("--skip-tls-speed", action="store_true", help="When parse mode is set to TLS, this flag indicates to skip parsing TLS speed results")
    
    # Parse the command line arguments
    try:
    
        # Take in the command line arguments
        args = parser.parse_args()
        parse_mode = args.parse_mode
        machine_id = args.machine_id
        total_runs = args.total_runs
        energy_test_type = args.energy_test_type
        
        # Define valid parsing mode for the script
        valid_parse_modes = ["computational", "tls", "energy"]

        # Ensure that a parsing mode has been provided and is valid
        if parse_mode is not None:
            if parse_mode not in valid_parse_modes:
                raise Exception(f"[ERROR] - Invalid parse mode provided to the script - {parse_mode}, please use 'computational', 'tls', or 'energy'")
        else:
            raise Exception("[ERROR] - No parsing mode provided, please use the --parse-mode argument to specify the parsing mode to be used")

        # Determine if a machine-ID has been provided to the script
        if machine_id is not None:

            # Check if the machine-ID is a valid integer
            if machine_id < 0 or not isinstance(machine_id, int):
                raise Exception(f"[ERROR] - Invalid Machine-ID provided to the script - {machine_id}, please use a positive integer value")
        
        # Ensure that the number of runs is present and is a valid integer
        if total_runs is not None and (total_runs < 1 or not isinstance(total_runs, int)):
            raise Exception(f"[ERROR] - Invalid number of runs provided to the script - {total_runs}, please use a positive integer value")

        # Ensure that both arguments are provided if they are both valid
        if machine_id is None or parse_mode is None or total_runs is None:
            raise Exception("[ERROR] - The --machine-id, --parse-mode, and --total-runs arguments must all be provided.")
        
        # Ensure that if energy parsing is selected, the energy test type argument is also provided and valid
        if parse_mode == "energy":
            
            # Define the valid energy test types
            valid_energy_test_types = {1: "pqc_performance_energy_results", 2: "tls_handshake_energy_results", 3: "tls_speed_energy_results"}

            # Check that the energy test type argument is provided and valid
            if energy_test_type is not None:
                if energy_test_type not in valid_energy_test_types.keys():
                    raise Exception(f"[ERROR] - Invalid energy test type provided to the script - {energy_test_type}")
            else:
                raise Exception("[ERROR] - The --energy-test-type argument must be provided if --parse-mode is set to energy parsing mode")
            
            # Store the energy test type string in the args namespace for use in the main function
            args.energy_test_type = valid_energy_test_types[energy_test_type]

        # Ensure that if skip tls speed flag has been set, that the parsing mode is TLS
        if args.skip_tls_speed and parse_mode != "tls":
            raise Exception("The --skip-tls-speed flag can only be used when the --parse-mode argument is set to 'tls'")
        
    except Exception as error:
        print(f"[ERROR] - {error}")
        parser.print_help()
        sys.exit(1)

    # Return the parsed arguments
    return args

#------------------------------------------------------------------------------------------------------------------------------
def setup_base_env():
    """ Function for setting up the global environment by determining the root path. It recursively moves up the directory 
        tree until it finds the .pqc_leo_dir_marker.tmp file, then returns the root path. """

    # Determine the directory that the script is being executed from and set the marker filename
    script_dir = os.path.dirname(os.path.abspath(__file__))
    current_dir = script_dir
    marker_filename = ".pqc_leo_dir_marker.tmp"

    # Continue moving up the directory tree until the .pqc_leo_dir_marker.tmp file is found
    while True:

        # Check if the .pqc_leo_dir_marker.tmp file is present
        if os.path.isfile(os.path.join(current_dir, marker_filename)):
            root_dir = current_dir
            return root_dir

        # Move up a directory and store the new path
        current_dir = os.path.dirname(current_dir)

        # If the system's root directory is reached and the file is not found, exit the script
        if current_dir == "/":
            print("[ERROR] - Root directory path file not present, please ensure the path is correct and try again.")
            sys.exit(1)

#------------------------------------------------------------------------------------------------------------------------------
def get_mode_selection():
    """ Helper function for getting the mode selection from the user if the interactive method of calling the script 
        is used. The function outputs the available options to the user and returns the selected option. """

    # Get the mode selection from the user
    while True:

        # Output the parsing options to the user and store the response
        print("Please select one of the following parsing options:")
        print("1 - Parse computational performance results")
        print("2 - Parse TLS performance results")
        print("3 - Parse energy consumption results")
        print("4 - Exit")
        user_parse_mode = input("Enter your choice (1-4): ")

        # Check if the user input is valid and return the selected option
        if user_parse_mode in ['1', '2', '3', '4']:

            # If exit is selected, print the exit message and return the option
            if user_parse_mode == '4':
                print("Exiting...")
                sys.exit(0)

            # Return the selected option
            return user_parse_mode
            
        else:
            print("[WARNING] - Invalid option, please select a valid option value (1-4)")

#------------------------------------------------------------------------------------------------------------------------------
def get_test_opts(root_dir, user_parse_mode):
    """ Helper function for getting the parsing mode from the user in interactive mode. It displays the available options 
        and returns the selected choice. """
    
    # Define the test_opts list that will store parsing parameters
    test_opts = {}

    # If performing energy usage metrics parsing, get the type of testing performed
    if user_parse_mode == "3":

        # Prompt the user to select the testing type until a valid input is provided
        while True:

            # Output the available test type options to the user
            print("Please select from the available energy usage testing types:")
            print("1) PQC Performance Energy Testing")
            print("2) TLS Handshake Performance Energy Testing")
            print("3) TLS Speed Performance Energy Testing")
            
            # Attempt to read in the users response and determine their choice
            try:

                # Prompt the user for their selection
                test_type_choice = int(input("Enter energy usage testing type to be parsed: "))

                # Set the test type based on the provided response
                if test_type_choice == 1:
                    test_opts["eng_test_type"] = "pqc_performance_energy_results"
                    break

                elif test_type_choice == 2:
                    test_opts["eng_test_type"] = "tls_handshake_energy_results"
                    break

                elif test_type_choice == 3:
                    test_opts["eng_test_type"] = "tls_speed_energy_results"
                    break

                else:
                    raise ValueError

            except ValueError:
                print(f"[ERROR] - Invalid input, please enter a valid testing type option\n")

    # Get the Machine-ID to be parsed from the user
    while True:
        try:
            machine_num = int(input("Enter the Machine-ID to be parsed - "))
            test_opts["machine_id"] = machine_num
            break

        except ValueError:
            print("[ERROR] - Invalid Input - Please enter a number!")
    
    # Get the total number of test runs from the user
    while True:

        try:
            # Prompt the user for the total of test runs
            total_runs = int(input("Enter the number of test runs performed - "))
            
            # Check if the total runs is more than 0
            if total_runs < 1:
                print("[ERROR] - Invalid Input - Please enter a number greater than 0!")
            else:
                test_opts["total_runs"] = total_runs
                break
            
        except ValueError:
            print("[ERROR] - Invalid Input - Please enter a valid number!")

    # Add the root_dir to the test options and return it
    test_opts["root_dir"] = root_dir
    return test_opts

#------------------------------------------------------------------------------------------------------------------------------
def check_skip_tls_speed():
    """ Helper function for checking if TLS speed results need to be skipped during parsing. It prompts the user for their
        preference and returns a boolean value indicating whether to skip TLS speed results. This helper function is only 
        needed if the script has been called in interactive mode and the parsing mode is set to TLS performance results. """

    # Output the informational message to the user on why they may need to skip TLS speed results
    print("If processing TLS performance results as part of energy usage testing, TLS speed results are not generated, so must be skipped.")

    # Prompt the user on their preference for skipping TLS speed results until a valid input is provided
    while True:

        # Prompt the user for their selection
        skip_tls_speed_input = input("Do you need to skip parsing TLS speed results? (y/n): ").strip().lower()

        # Check if the user input is valid and set the skip_tls_speed flag accordingly
        if skip_tls_speed_input in ['y', 'yes']:
            skip_tls_speed = True
            break

        elif skip_tls_speed_input in ['n', 'no']:
            skip_tls_speed = False
            break
        
        else:
            print("[ERROR] - Invalid input, please enter 'y' or 'n'.")

    return skip_tls_speed

#------------------------------------------------------------------------------------------------------------------------------
def main():
    """ Main function for controlling the parsing of computational and TLS performance testing results. Handles both 
        command-line and interactive modes to process results based on user input. """

    # Setup the base environment for the script
    root_dir = setup_base_env()

    # Set the default value for the replace_old_results and skip_tls_speed flags
    replace_old_results = False
    skip_tls_speed = False

    # Define the local machine_id variable for use in the final output message
    local_machine_id = None

    # Determine which method is being used to run the script
    if len (sys.argv) > 1:

        # Parse the command line arguments provided to the script
        args = handle_args()

        # Set the local machine_id variable for use in the final output message
        local_machine_id = args.machine_id

        # Determine if existing results should be replaced
        if args.replace_old_results:
            replace_old_results = True
        else:
            replace_old_results = False

        # Determine which parsing mode to use and get the test options
        if args.parse_mode == "computational":

            # Output the parsing type to the terminal
            print(f"Parsing Computational Performance Results...\n")

            # Define the test options and call the relevant internal parsing script
            comp_test_opts = {
                "machine_id": args.machine_id, 
                "total_runs": args.total_runs, 
                "root_dir": root_dir
            }
            parse_comp_performance(comp_test_opts, replace_old_results)
        
        elif args.parse_mode == "tls":

            # Output the parsing type to the terminal
            print(f"Parsing TLS Performance Results...\n")

            # Determine if TLS speed results should be skipped based on the command line argument
            if args.skip_tls_speed:
                skip_tls_speed = True

            # Define the test options and call the relevant internal parsing script
            tls_test_opts = {
                "machine_id": args.machine_id, 
                "total_runs": args.total_runs,
                "root_dir": root_dir
            }
            parse_tls_performance(tls_test_opts, replace_old_results, skip_tls_speed)

        elif args.parse_mode == "energy":

            # Output the parsing type to the terminal
            print(f"Parsing Energy Consumption Results...\n")

            # Define the test options and call the relevant internal parsing script
            energy_test_opts = {
                "machine_id": args.machine_id, 
                "total_runs": args.total_runs, 
                "eng_test_type": args.energy_test_type, 
                "root_dir": root_dir
            }
            parse_energy_data(energy_test_opts, replace_old_results)

    else:

        # Output the greeting message to the terminal
        print("###########################")
        print("PQC-LEO Result Parsing Tool")
        print(f"###########################\n")

        # Get the parsing mode from the user
        user_parse_mode = get_mode_selection()

        # Determine the parsing mode based on the user response
        if user_parse_mode == '1':

            # Output the selected parsing option
            print("Parsing computational performance results selected")

            # Get the test options used for the benchmarking
            print(f"\n---------------------------------------------------------------")
            print(f"Gathering testing parameters used for computational performance")
            print(f"---------------------------------------------------------------")
            comp_test_opts = get_test_opts(root_dir, user_parse_mode)

            # Set the local machine_id variable for use in the final output message
            local_machine_id = comp_test_opts["machine_id"]

            # Call the parsing script for Liboqs results
            print("Processing results...")
            parse_comp_performance(comp_test_opts, replace_old_results)
        
        elif user_parse_mode == '2':

            # Output the selected parsing option
            print("Parsing TLS performance results selected")

            # Get the test options used for the benchmarking
            print(f"\n--------------------------------------------------------")
            print(f"Gathering testing parameters for TLS performance testing")
            print(f"--------------------------------------------------------")
            tls_test_opts = get_test_opts(root_dir, user_parse_mode)

            # Set the local machine_id variable for use in the final output message
            local_machine_id = tls_test_opts["machine_id"]

            # Figure out if TLS speed results need skipped
            skip_tls_speed =  check_skip_tls_speed()

            # Call the parsing script for OQS-Provider TLS results
            print("Processing results...")
            parse_tls_performance(tls_test_opts, replace_old_results, skip_tls_speed)

        elif user_parse_mode == '3':

            # Output the selected parsing option
            print("Parsing energy consumption results selected")

            # Get the test options used for the benchmarking
            print(f"\n----------------------------------------------------------------")
            print(f"Gathering testing parameters used for energy consumption testing")
            print(f"----------------------------------------------------------------")
            energy_test_opts = get_test_opts(root_dir, user_parse_mode)

            # Set the local machine_id variable for use in the final output message
            local_machine_id = energy_test_opts["machine_id"]

            # Call the parsing script for energy consumption results
            print(f"Processing results...\n")
            parse_energy_data(energy_test_opts, replace_old_results)

        else:
            print(f"[ERROR] - Invalid value in the parsing mode variable - {user_parse_mode}")
            sys.exit(1)

    # Output the parsing completed message to the terminal
    print(f"Results processing complete, parsed results can be found in the following directory:")
    print(f"{os.path.join(root_dir, 'test-data', 'results', f'machine_{local_machine_id}')}")

#------------------------------------------------------------------------------------------------------------------------------
"""Main boiler plate"""
if __name__ == "__main__":
    main()