"""
Copyright (c) 2023-2025 Callum Turino
SPDX-License-Identifier: MIT

Controller script for parsing PQC performance results produced by the Liboqs and OQS-Provider testing tools.
It allows the user to parse Liboqs, OQS-Provider, or both result sets by either supplying parameters via command-line
arguments or using an interactive prompt. The script collects the required test parameters (e.g., Machine-ID and number
of test runs), invokes the appropriate parsing modules, and outputs cleaned, formatted CSV files to the results directory
at the project root. Parsing is supported only on Linux systems and depends on the presence of the original algorithm list files
used for testing.
"""

#------------------------------------------------------------------------------------------------------------------------------
from internal_scripts.performance_data_parse import parse_liboqs
from internal_scripts.tls_performance_data_parse import parse_oqs_provider
import os
import sys
import argparse

#------------------------------------------------------------------------------------------------------------------------------
def handle_args():
    """ Function for handling the command line arguments passed to the script. The function uses the argparse
        library to define the expected arguments and their types. The function returns the parsed arguments if valid. """
    
    # Define the argument parser and the valid options for the script
    parser = argparse.ArgumentParser(description="PQC-Evaluation-Tools Results Parsing Tool")
    parser.add_argument('--parse-mode', type=str, help='The parsing mode to be used (liboqs or oqs-provider)')
    parser.add_argument('--machine-id', type=int, help='The Machine-ID of the results to be parsed')
    parser.add_argument('--total-runs', type=int, help='The number of test runs to be parsed')
    parser.add_argument("--replace-old-results", action="store_true", help="Replace old results for the passed Machine-ID if this flag is set")
    
    # Parse the command line arguments
    try:
    
        # Take in the command line arguments
        args = parser.parse_args()
        parse_mode = args.parse_mode
        machine_id = args.machine_id
        total_runs = args.total_runs 

        # Check if the parse mode is valid (done manually to have custom error messages)
        if parse_mode == 'both':
            raise Exception("The --parse-mode argument cannot be set to 'both' for automatic parsing, please use the interactive mode from the terminal")
        
        elif parse_mode != "liboqs" and parse_mode != "oqs-provider":
            raise Exception(f"Invalid parse mode provided to the script - {parse_mode}, please use 'liboqs' or 'oqs-provider'")

        # Determine if a machine ID has been provided to the script
        if machine_id is not None:

            # Check if the machine ID is a valid integer
            if machine_id < 0 or not isinstance(machine_id, int):
                raise Exception(f"Invalid Machine-ID provided to the script - {machine_id}, please use a positive integer value")
            
        # Ensure that the number of runs is present and is a valid integer
        if total_runs is not None and (total_runs < 1 or not isinstance(total_runs, int)):
            raise Exception(f"Invalid number of runs provided to the script - {total_runs}, please use a positive integer value")

        # Ensure that both arguments are provided if they are both valid
        if machine_id is None or parse_mode is None or total_runs is None:
            raise Exception("The --machine-id, --parse-mode, and --total-runs arguments must all be provided.")

    except Exception as error:
        print(f"[ERROR] - {error}")
        parser.print_help()
        sys.exit(1)

    # Return the parsed arguments
    return args

#------------------------------------------------------------------------------------------------------------------------------
def setup_base_env():
    """ Function for setting up the global environment variables for the test suite. The function establishes
        the root path by determining the path of the script and recursively moving up the directory tree until
        it finds the .pqc_eval_dir_marker.tmp file. The root path is then returned to the main function. """
    
    # Determine the directory that the script is being executed from and set the marker filename
    script_dir = os.path.dirname(os.path.abspath(__file__))
    current_dir = script_dir
    marker_filename = ".pqc_eval_dir_marker.tmp"

    # Continue moving up the directory tree until the .pqc_eval_dir_marker.tmp file is found
    while True:

        # Check if the .pqc_eval_dir_marker.tmp file is present
        if os.path.isfile(os.path.join(current_dir, marker_filename)):
            root_dir = current_dir
            return root_dir

        # Move up a directory and store the new path
        current_dir = os.path.dirname(current_dir)

        # If the system's root directory is reached and the file is not found, exit the script
        if current_dir == "/":
            print("Root directory path file not present, please ensure the path is correct and try again.")
            sys.exit(1)

#------------------------------------------------------------------------------------------------------------------------------
def get_mode_selection():
    """ Helper function for getting the mode selection from the user if the interactive method of calling the script 
        is used. The function outputs the available options to the user and returns the selected option. """

    # Get the mode selection from the user
    while True:

        # Output the parsing options to user and store the response
        print("Please select one of the following Parsing options:")
        print("1 - Parse Liboqs results")
        print("2 - Parse OQS-Provider results")
        print("3 - Parse both Liboqs and OQS-Provider results")
        print("4 - Exit")
        user_parse_mode = input("Enter your choice (1-4): ")
        print(f"\n")

        # Check if the user input is valid and return the selected option
        if user_parse_mode in ['1', '2', '3', '4']:

            # If exit is selected, print the exit message and return the option
            if user_parse_mode == '4':
                print("Exiting...")
                sys.exit(0)

            # Return the selected option
            return user_parse_mode
            
        else:
            print(["Invalid option, please select a valid option value (1-4)"])

#------------------------------------------------------------------------------------------------------------------------------
def get_test_opts(root_dir):
    """ Helper function for getting the test parameters used in during the automated testing, which includes 
        the number of runs and number of machines tested. """
    
    # Output the greeting message to the terminal
    print(f"PQC-Evaluation-Tools Results Parsing Tool\n\n")

    # Get the Machine-ID to be parsed from the user
    while True:
        try:
            machine_num = int(input("Enter the Machine-ID to be parsed - "))
            break
        except ValueError:
            print("Invalid Input - Please enter a number!")
    
    # Get the total number of test runs from the user
    while True:

        try:
            # Prompt the user for the total of test runs
            total_runs = int(input("Enter the number of test runs performed - "))

            # Check if the total runs is more than 0
            if total_runs < 1:
                print("Invalid Input - Please enter a number greater than 0!")
            else:
                break
            
        except ValueError:
            print("Invalid Input - Please enter a valid number!")
    
    test_opts = [machine_num, total_runs, root_dir]
    return test_opts

#------------------------------------------------------------------------------------------------------------------------------
def main():
    """Main function which controls the parsing scripts for Liboqs and OQS-Provider testing results"""

    # Setup the base environment for the script
    root_dir = setup_base_env()

    # Set the default value for the replace_old_results variable
    replace_old_results = False

    # Determine which method is being used to the run the script
    if len (sys.argv) > 1:

        # Parse the command line arguments provided to the script
        args = handle_args()

        # Determine if existing results should be replaced
        if args.replace_old_results:
            replace_old_results = True
        else:
            replace_old_results = False

        # Determine which parsing mode to use and get the test options
        if args.parse_mode == "liboqs":
            print("Parsing Liboqs results")
            liboqs_test_opts = [args.machine_id, args.total_runs, root_dir]
            parse_liboqs(liboqs_test_opts, replace_old_results)
        
        elif args.parse_mode == "oqs-provider":
            print("Parsing OQS-Provider results")
            oqs_provider_test_opts = [args.machine_id, args.total_runs, root_dir]
            parse_oqs_provider(oqs_provider_test_opts, replace_old_results)

    else:

        # Get the parsing mode from the user
        user_parse_mode = get_mode_selection()

        # Determine the parsing mode based on the user response
        if user_parse_mode == '1':

            # Output the selected parsing option
            print("Parsing only Liboqs results selected")

            # Get the test options used for the benchmarking
            print(f"Setting total liboqs machine results\n")
            liboqs_test_opts = get_test_opts(root_dir)

            # Call the parsing script for Liboqs results
            parse_liboqs(liboqs_test_opts, replace_old_results)
        
        elif user_parse_mode == '2':

            # Output the selected parsing option
            print("Parsing only OQS-Provider results selected")

            # Get the test options used for the benchmarking
            print(f"Setting total OQS-Provider machine results\n")
            oqs_provider_test_opts = get_test_opts(root_dir)

            # Call the parsing script for OQS-Provider TLS results
            parse_oqs_provider(oqs_provider_test_opts, replace_old_results)

        elif user_parse_mode == '3':

            # Output the selected parsing option
            print("Parsing both result sets selected")

            # Get the test options used for the benchmarking
            print(f"Setting total Liboqs machine results\n")
            liboqs_test_opts = get_test_opts(root_dir)

            print(f"\nSetting total OQS-Provider machine results\n")
            oqs_provider_test_opts = get_test_opts(root_dir)
            
            # Parse the Liboqs results
            parse_liboqs(liboqs_test_opts, replace_old_results)
            print("Liboqs Parsing complete\n")

            # Parse the OQS-Provider Results
            parse_oqs_provider(oqs_provider_test_opts, replace_old_results)
            print("OQS-Provider Parsing complete\n")

        else:
            print(f"[ERROR] - Invalid value in the parsing mode variable - {user_parse_mode}")
            sys.exit(1)

    # Output the parsing completed message to the terminal
    print(f"Results processing complete, parsed results can be found in the following directory:")
    print(f"{os.path.join(root_dir, 'test-data', 'results')}")

#------------------------------------------------------------------------------------------------------------------------------
"""Main boiler plate"""
if __name__ == "__main__":
    main()