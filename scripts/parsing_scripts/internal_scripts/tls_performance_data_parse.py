"""
Copyright (c) 2023-2025 Callum Turino
SPDX-License-Identifier: MIT

OQS-Provider result parsing script for PQC TLS performance benchmarking.  
Parses raw TLS handshake and OpenSSL speed test outputs produced by the automated OQS-Provider test suite,  
structures the results into clean CSV files, and computes averaged metrics using the results_averager module.  
This script is called by the central parse_results.py controller and supports single-machine, multi-run setups.
"""

#------------------------------------------------------------------------------------------------------------------------------
import pandas as pd
import os
import sys
import shutil
import time
from internal_scripts.results_averager import OqsProviderResultAverager

#------------------------------------------------------------------------------------------------------------------------------
def setup_parse_env(root_dir):
    """ Function for setting up the environment for the OQS-Provider TLS parsing script. The function
        will set the various directory paths, read in the algorithm lists, set the root directories 
        and set the column headers for the CSV files that will be outputted. """

    # Define the central paths dictionary that will be used by the various methods and functions
    dir_paths = {}

    # Ensure the root_dir path is correct before continuing
    if not os.path.isfile(os.path.join(root_dir, ".pqc_eval_dir_marker.tmp")):
        print("Project root directory path file not correct, the main parse_results.py file is not able to establish the correct path!!!")
        sys.exit(1)

    # Note: (at some point consider making these vars into a json file)

    # Declare the algorithms dictionary that will be used by the various methods and functions
    algs_dict = {
        'kem_algs': [], 
        'sig_algs': [],
        "hybrid_kem_algs": [],
        "hybrid_sig_algs": [],
        "speed_kem_algs": [],
        "speed_sig_algs": [],
        "hybrid_speed_kem_algs": [],
        "hybrid_speed_sig_algs": [],
        'classic_algs': ["RSA_2048", "RSA_3072", "RSA_4096", "prime256v1", "secp384r1", "secp521r1"], 
        'ciphers': ["TLS_AES_256_GCM_SHA384", "TLS_CHACHA20_POLY1305_SHA256", "TLS_AES_128_GCM_SHA256"]
    }

    # Declare the column headers dictionary that will be used by the various methods and functions
    col_headers = {
        'pqc_based_headers': ["Signing Algorithm", "KEM Algorithm", "Reused Session ID", "Connections in User Time", "User Time (s)", "Connections Per User Second", "Connections in Real Time", "Real Time (s)"],
        'classic_headers': ["Ciphersuite", "Classic Algorithm", "Reused Session ID", "Connections in User Time", "User Time (s)", "Connections Per User Second", "Connections in Real Time", "Real Time (s)"]

    }

    # Declare the dictionary which will contain the respective keys for alg_dict and dir_paths for PQC and PQC-Hybrid results
    pqc_type_vars = {
        "kem_alg_type": ["kem_algs", "hybrid_kem_algs"],
        "sig_alg_type": ["sig_algs", "hybrid_sig_algs"],
        "up_results_path": "",
        "results_type": ["pqc_handshake_results", "hybrid_handshake_results"],
        "type_prefix": ["pqc", "hybrid"],
        "base_type": ["pqc_base_results", "hybrid_base_results"]
    }

    # Declare the dictionary which contains testing types and defining the speed column headers
    speed_type_vars = {"PQC": "", "Hybrid": ""}
    speed_headers = [
        ["Algorithm", "Keygen", "encaps", "decaps", "Keygen/s", "Encaps/s", "Decaps/s"], 
        ["Algorithm", "Keygen", "Signs", "Verify", "Keygen/s", "sign/s", "verify/s"]
    ]

    # Set the test results directory paths in the central paths dictionary
    dir_paths['root_dir'] = root_dir
    dir_paths['results_dir'] = os.path.join(root_dir, "test_data", "results", "oqs_provider")
    dir_paths['up_results'] = os.path.join(root_dir, "test_data", "up_results", "oqs_provider")

    # Set the alg-list filenames for the various PQC test types (PQC and PQC-Hybrid)
    alg_list_files = {
        "kem_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_kem_algs.txt"),
        "sig_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_sig_algs.txt"),
        "hybrid_kem_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_hybr_kem_algs.txt"),
        "hybrid_sig_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_hybr_sig_algs.txt"),
        "speed_kem_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_speed_kem_algs.txt"),
        "speed_sig_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_speed_sig_algs.txt"),
        "hybrid_speed_kem_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_speed_hybr_kem_algs.txt"),
        "hybrid_speed_sig_algs": os.path.join(root_dir, "test_data", "alg_lists", "tls_speed_hybr_sig_algs.txt"),
    }

    # Pull the algorithm names from the alg-lists files and create the relevant alg lists
    for alg_type, filepath in alg_list_files.items():
        with open(filepath, "r") as alg_file:
            for line in alg_file:
                algs_dict[alg_type].append(line.strip())

    # Empty the alg_list_files dict as no longer needed
    alg_list_files = None

    return dir_paths, algs_dict, pqc_type_vars, col_headers, speed_headers

#------------------------------------------------------------------------------------------------------------------------------
def handle_results_dir_creation(machine_id, dir_paths, replace_old_results):
    """ Function for handling the presence of older parsed results, ensuring that the user
        is aware of the old results and can choose how to handle them before the parsing continues. """

    # Check if there are any old parsed results for current Machine-ID and handle any clashes
    if os.path.exists(dir_paths["mach_results_dir"]):

        # Determine if the user needs prompted to handle the old results or if the --replace-old-results flag is set
        if replace_old_results:

            # Output the warning message about the old results
            print(f"[NOTICE] - The --replace-old-results flag has been set, replacing the old results for Machine-ID ({machine_id})\n")
            time.sleep(2)

            # Replace all old results and create a new empty directory to store the parsed results
            print(f"Removing old results directory for Machine-ID ({machine_id}) before continuing...\n")
            shutil.rmtree(dir_paths["results_dir"], f"machine_{machine_id}")

            # Create the new directories for parsed results
            os.makedirs(dir_paths["mach_handshake_dir"])
            os.makedirs(dir_paths["mach_speed_results_dir"])
        
        else:

            # Output the warning message to the terminal
            print(f"[WARNING] - There are already parsed OQS-Provider testing results present for Machine-ID ({machine_id})\n")

            # Get the decision from user on how to handle old results before parsing continues
            while True:

                # Output the potential options and handle user choice
                print(f"From the following options, choose how would you like to handle the old OQS-Provider results:\n")
                print("Option 1 - Replace old parsed results with new ones")
                print("Option 2 - Exit parsing programme to move old results and rerun after (if you choose this option, please move the entire folder not just its contents)")
                print("Option 3 - Make parsing script programme wait until you have move files before continuing")
                user_choice = input("Enter option: ")

                if user_choice == "1":

                    # Replace all old results and create a new empty directory to store the parsed results
                    print(f"Removing old results directory for Machine-ID ({machine_id}) before continuing...\n")
                    shutil.rmtree(dir_paths["results_dir"], f"machine_{machine_id}")

                    # Create the new directories for parsed results
                    os.makedirs(dir_paths["mach_handshake_dir"])
                    os.makedirs(dir_paths["mach_speed_results_dir"])
                    break

                elif user_choice == "2":

                    # Exit the script to allow the user to move old results before retrying
                    print("Exiting parsing script...")
                    exit()

                elif user_choice == "3":

                    # Halting script until old results have been moved for current Machine-ID
                    while True:

                        input(f"Halting parsing script so old parsed results for Machine-ID ({machine_id}) can be moved, press enter to continue")

                        # Checking if old results have been moved before continuing
                        if os.path.exists(dir_paths["mach_results_dir"]):
                            print(f"Old parsed results for Machine-ID ({machine_id}) still present!!!\n")

                        else:
                            print("Old results have been moved, now continuing with parsing script")
                            os.makedirs(dir_paths["mach_handshake_dir"])
                            os.makedirs(dir_paths["mach_speed_results_dir"])
                            break
                    
                    break

                else:
                    
                    # Output the warning message if the user input is not valid
                    print("Incorrect value, please select (1/2/3)")

    else:
        
        # No old parsed results for current machine-id present so creating new dirs
        os.makedirs(dir_paths["mach_handshake_dir"])
        os.makedirs(dir_paths["mach_speed_results_dir"])

#------------------------------------------------------------------------------------------------------------------------------
def get_metrics(current_row, test_filepath, get_reuse_metrics):
    """ Helper function for pulling the current sig/kem metrics from 
        the supplied OQS-Provider s_time output file. """

    # Get the relevant data from the supplied performance metrics output file
    try:

        # Open the file and extract the metrics
        with open(test_filepath, "r") as test_file:

            # Set flag used to determine metric type (first use or session id reused)
            session_metrics_flag = False

            # Loop through the file lines to pull the performance metrics
            for line in test_file:

                # Check the line to see if metrics are for session id first use or reused
                if "reuse" in line:
                    session_metrics_flag = True

                # Get line 1 metrics using keywords
                if "connections" in line and "user" in line:

                    # Check if metrics is session first use or reuse
                    if session_metrics_flag is False and get_reuse_metrics is False:

                        # Store line 1 first use metrics
                        separated_line = line.split()
                        current_row.append(separated_line[0])
                        current_row.append(separated_line[3][:-2])
                        current_row.append(separated_line[4])

                    elif session_metrics_flag is True and get_reuse_metrics is True:

                        # Store line 1 session id reuse metrics
                        separated_line = line.split()
                        current_row.append(separated_line[0])
                        current_row.append(separated_line[3][:-2])
                        current_row.append(separated_line[4])
                
                # Get line 2 metrics using keywords
                elif "connections" in line and "real" in line:

                    # Check if metrics is first use or reuse
                    if session_metrics_flag is False and get_reuse_metrics is False:

                        # Store line 2 first use metrics
                        separated_line = line.split()
                        current_row.append(separated_line[0])
                        current_row.append(separated_line[3])
                        break

                    elif session_metrics_flag is True and get_reuse_metrics is True:

                        # Store line 2 session id reuse metrics
                        separated_line = line.split()
                        current_row.append(separated_line[0])
                        current_row.append(separated_line[3])

    except:

        # Output the file not found error and the missing filename
        print(f"missing file - {test_filepath}")

        # Create an empty row as placeholder for missing file
        for _ in range(1,6):
            current_row.append("")

    return current_row

#------------------------------------------------------------------------------------------------------------------------------
def pqc_based_pre_processing(current_run, type_index, pqc_type_vars, col_headers, algs_dict, dir_paths):
    """ Function for pre-processing PQC and PQC-Hybrid TLS results for the current run. This function
        will loop through the sig/kem combinations and extract the metrics for each combination. This creates the 
        full base results for the current run which can later be separated into individual CSV files for each sig/kem combo """
    
    # Check if the stored up-results matches the number of algorithms in the alg list files only if run 1
    if current_run == 1:

        # Determine the number of expected and actual result files in the up-results directory
        up_results_dir = pqc_type_vars["up_results_path"][type_index]
        expected_files = len(algs_dict[pqc_type_vars["sig_alg_type"][type_index]]) * len(algs_dict[pqc_type_vars["kem_alg_type"][type_index]])
        actual_files = [file for file in os.listdir(up_results_dir) if file.startswith("tls_handshake_1_") and file.endswith(".txt")]

        # Ensure that the up-results directory for current PQC type and run contains the correct number of files
        if expected_files != len(actual_files):
            print(f"\n[ERROR] - Mismatch in expected file count for {pqc_type_vars['type_prefix'][type_index].upper()} TLS Handshake results.")
            print(f"Please ensure the alg-list files have the same algorithms used in the testing, the setup process may need to be re-run")
            print(f"If that is the case, please ensure to copy the up-results directory to a safe location before re-running the setup script")
            sys.exit(1)

    # Declare the dataframe used in pre-processing
    sig_metrics_df = pd.DataFrame(columns=col_headers['pqc_based_headers'])

    # Loop through the sig list to create the csv
    for sig in algs_dict[pqc_type_vars["sig_alg_type"][type_index]]:

        # Loop through the KEM files signed with the current sig
        for kem in algs_dict[pqc_type_vars["kem_alg_type"][type_index]]:

            # Set the filename and path
            filename = f"tls_handshake_{current_run}_{sig}_{kem}.txt"
            test_filepath = os.path.join(pqc_type_vars["up_results_path"][type_index], filename)
            
            # Get the session id first use metrics for the current KEM
            current_row = [kem, ""]
            current_row = get_metrics(current_row, test_filepath, get_reuse_metrics=False)
            current_row.insert(0, sig)

            # Add the session id first use row to the dataframe
            new_row_df = pd.DataFrame([current_row], columns=col_headers['pqc_based_headers'])
            sig_metrics_df = pd.concat([sig_metrics_df, new_row_df], ignore_index=True)
            current_row.clear()

            # Get the session id reused metrics for the current KEM
            current_row = [kem, "*"]
            current_row = get_metrics(current_row, test_filepath, get_reuse_metrics=True)
            current_row.insert(0, sig)

            # Add the session id reused use row to the dataframe
            new_row_df = pd.DataFrame([current_row], columns=col_headers['pqc_based_headers'])
            sig_metrics_df = pd.concat([sig_metrics_df, new_row_df], ignore_index=True)
            current_row.clear()

    # Output the full base PQC TLS metrics for the current run
    base_out_filename = f"{pqc_type_vars['type_prefix'][type_index]}_base_results_run_{current_run}.csv"
    output_filepath = os.path.join(dir_paths[pqc_type_vars["base_type"][type_index]], base_out_filename)
    sig_metrics_df.to_csv(output_filepath,index=False)

#------------------------------------------------------------------------------------------------------------------------------
def pqc_based_processing(current_run, dir_paths, algs_dict, pqc_type_vars, col_headers):
    """ Function for parsing both PQC and PQC-Hybrid TLS results for the current run. The function will
        process the results and output the full base results for the current run and then separate the
        results into individual CSV files for each sig/kem combo. This will be done for both PQC and PQC-Hybrid. """

    # Process the results for both PQC (0) and PQC-Hybrid (1) TLS results
    for type_index in range (0,2):

        # Perform pre-processing for the current test type
        pqc_based_pre_processing(current_run, type_index, pqc_type_vars, col_headers, algs_dict, dir_paths)

        # Set the base results filename and path based on current run
        pqc_base_filename = f"{pqc_type_vars['type_prefix'][type_index]}_base_results_run_{current_run}.csv"
        pqc_base_filepath = os.path.join(dir_paths[pqc_type_vars["base_type"][type_index]], pqc_base_filename)

        # Create the storage directory and files for separated sig/kem combo results
        for sig in algs_dict[pqc_type_vars["sig_alg_type"][type_index]]:

            # Set the path for sig/kem combo directory
            sig_path = os.path.join(dir_paths[pqc_type_vars["results_type"][type_index]], sig)

            # Create the storage dir for separated sig/kem combo results if not made
            if not os.path.exists(sig_path):
                os.makedirs(sig_path)
            
            # Read in the current run base results and extracting signature
            base_df = pd.read_csv(pqc_base_filepath)
            current_sig_df = base_df[base_df["Signing Algorithm"].str.contains(sig)]

            # Output the current sig filtered df to csv
            output_filename = f"tls_handshake_{sig}_run_{current_run}.csv"
            output_filepath = os.path.join(sig_path, output_filename)
            current_sig_df.to_csv(output_filepath, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def classic_based_processing(current_run, dir_paths, algs_dict, col_headers):
    """ Function for processing results from classic cipher TLS handshake testing """

    # Set the up-results directory path and create the dataframe used in test processing
    classic_up_results_dir = os.path.join(dir_paths['mach_up_results_dir'], "handshake-results", "classic")
    cipher_metrics_df = pd.DataFrame(columns=col_headers['classic_headers'])

    # Loop through each ciphersuite
    for cipher in algs_dict['ciphers']:

        # Looping through each digital signature algorithm for the current ciphersuite
        for alg in algs_dict['classic_algs']:

            # Set the filename and path
            filename = f"tls_handshake_classic_{current_run}_{cipher}_{alg}.txt"
            test_filepath = os.path.join(classic_up_results_dir, filename)
            
            # Get the session id first use metrics for the current signature
            current_row = [alg, ""]
            current_row = get_metrics(current_row, test_filepath, get_reuse_metrics=False)
            current_row.insert(0, cipher)

            # Add the session id first use row to dataframe
            new_row_df = pd.DataFrame([current_row], columns=col_headers['classic_headers'])
            cipher_metrics_df = pd.concat([cipher_metrics_df, new_row_df], ignore_index=True)
            current_row.clear()
            
            # Get the session id reused metrics for the current signature
            current_row = [alg, "*"]
            current_row = get_metrics(current_row, test_filepath, get_reuse_metrics=True)
            current_row.insert(0, cipher)

            # Add the session id reused use row to dataframe
            new_row_df = pd.DataFrame([current_row], columns=col_headers['classic_headers'])
            cipher_metrics_df = pd.concat([cipher_metrics_df, new_row_df], ignore_index=True)
            current_row.clear()

    # Output the full base Classic TLS metrics for current run
    cipher_out_filename = f"classic_results_run_{current_run}.csv"
    output_filepath = os.path.join(dir_paths['classic_handshake_results'], cipher_out_filename)
    cipher_metrics_df.to_csv(output_filepath, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def tls_speed_drop_last(data_cells):
    """ Helper function for removing unwanted characters from 
        metric values during the tls-speed results parsing """

    # Loop through the values and remove any s chars present in metrics
    for cell_index in range(1, len(data_cells)):
        cell_value = data_cells[cell_index]
        if "s" in cell_value:
            data_cells[cell_index] = data_cells[cell_index].replace('s', '')

    return data_cells

#------------------------------------------------------------------------------------------------------------------------------
def get_speed_metrics(speed_filepath, alg_type, speed_headers):
    """ Function for extracting the speed metrics from the raw OpenSSL s_speed tool with OQS-Provider output file 
        for the current algorithm type (kem or sig) """

    # Declare the variables needed for getting metrics and setting up the dataframe with test/alg type headers
    start = False
    data_lists = []
    headers = speed_headers[0] if alg_type == "kem" else speed_headers[1]
    speed_metrics_df = pd.DataFrame(columns=headers)

    # Open the file and extract metrics
    with open(speed_filepath, "r") as speed_file:
        for line in speed_file:

            # Check to see if result table has started
            if "keygens/s" in line:
                start = True
                continue
            elif "sign" in line and "verify" in line:
                start = True
                continue

            # If the result table has started, extract data
            if start:
                data_lists.append(line.strip())
    
    # Append the data onto the dataframe
    for data in data_lists:

        # Insert the alg name to the row
        data_cells = data.split()

        # Remove any s char present in speed metric values for the row
        data_cells = tls_speed_drop_last(data_cells)

        # Add the new data row to the speed metrics data frame
        new_row_df = pd.DataFrame([data_cells], columns=headers)
        speed_metrics_df = pd.concat([speed_metrics_df, new_row_df], ignore_index=True)

    return speed_metrics_df

#------------------------------------------------------------------------------------------------------------------------------
def speed_processing(current_run, dir_paths, speed_headers, algs_dict):
    """ Function for processing OpenSSL s_speed with OQS_Provider metrics for both PQC and PQC-Hybrid algorithms
       for the current run """

    # Define the alg type list 
    alg_types = ["kem", "sig"]

    # Loop through the test types and process up-results for speed metrics
    for test_type, dir_list in dir_paths['speed_types_dirs'].items():

        # Set the file prefix depending on the current test type
        pqc_fileprefix = "tls_speed" if test_type == "pqc" else "tls_speed_hybrid"

        # Process both the KEM and signature results for the current test type
        for alg_type in alg_types:

            # Set the up-results filepath and pull metrics from the raw file
            speed_filepath = os.path.join(dir_list[0], f"{pqc_fileprefix}_{alg_type}_{str(current_run)}.txt")
            speed_metrics_df = get_speed_metrics(speed_filepath, alg_type, speed_headers)

            # Set the alg list dict key based on the current test and algorithm type
            alg_list_key = f"speed_{alg_type}_algs" if test_type == "pqc" else f"hybrid_speed_{alg_type}_algs"

            # Check if the number of speed metrics matches the expected number of algorithms
            if len(speed_metrics_df) != len(algs_dict[alg_list_key]):
                print(f"\n[ERROR] - Mismatch in expected entry count for {test_type.upper()} {alg_type.upper()} TLS Speed results.")
                print(f"Please ensure the alg-list files have the same algorithms used in the testing, the setup process may need to be re-run")
                print(f"If that is the case, please ensure to copy the up-results directory to a safe location before re-running the setup script")
                sys.exit(1)

            # Output the speed metrics csv for the current test type and algorithm
            output_filepath = os.path.join(dir_list[1], f"{pqc_fileprefix}-{alg_type}-{str(current_run)}.csv")
            speed_metrics_df.to_csv(output_filepath, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def output_processing(num_runs, dir_paths, algs_dict, pqc_type_vars, col_headers, speed_headers):
    """ Function for processing the outputs of the 
        s_time and s_speed TLS benchmarking tests for the current machine """
    
    # Set the result directories paths in the central paths dictionary
    dir_paths['pqc_handshake_results'] = os.path.join(dir_paths['mach_handshake_dir'], "pqc")
    dir_paths['classic_handshake_results'] = os.path.join(dir_paths['mach_handshake_dir'], "classic")
    dir_paths['hybrid_handshake_results'] = os.path.join(dir_paths['mach_handshake_dir'], "hybrid")
    dir_paths['pqc_base_results'] = os.path.join(dir_paths['pqc_handshake_results'], "base_results")
    dir_paths['hybrid_base_results'] = os.path.join(dir_paths['hybrid_handshake_results'], "base_results")

    # Set the base-results files directories for the different test types
    os.makedirs(dir_paths['pqc_base_results'])
    os.makedirs(dir_paths['classic_handshake_results'])
    os.makedirs(dir_paths['hybrid_base_results'])

    # Loop through the runs and call result processing functions
    for current_run in range(1, num_runs+1):
        pqc_based_processing(current_run, dir_paths, algs_dict, pqc_type_vars, col_headers)
        classic_based_processing(current_run, dir_paths, algs_dict, col_headers)
        speed_processing(current_run, dir_paths, speed_headers, algs_dict)

#------------------------------------------------------------------------------------------------------------------------------
def process_tests(machine_id, num_runs, dir_paths, algs_dict, pqc_type_vars, col_headers, speed_headers, replace_old_results):
    """ Function for controlling the parsing scripts for the OQS-Provider TLS testing up-result files
        and calling average  calculation scripts """

    # Create an instance of the OQS-Provider average generator class before processing results
    oqs_provider_avg = None
    oqs_provider_avg = OqsProviderResultAverager(dir_paths, num_runs, algs_dict, pqc_type_vars, col_headers)

    # Set the machine's results directories paths in the central paths dictionary
    dir_paths['mach_results_dir'] = os.path.join(dir_paths['results_dir'], f"machine_{str(machine_id)}")
    dir_paths['mach_up_results_dir'] = os.path.join(dir_paths['up_results'], f"machine_{str(machine_id)}")
    dir_paths['mach_handshake_dir']  = os.path.join(dir_paths['results_dir'], f"machine_{str(machine_id)}", "handshake_results")
    dir_paths['mach_up_speed_dir'] = os.path.join(dir_paths['up_results'], f"machine_{str(machine_id)}", "speed_results")
    dir_paths['mach_speed_results_dir'] = os.path.join(dir_paths['results_dir'], f"machine_{str(machine_id)}", "speed_results")
    dir_paths['speed_types_dirs'] = {
        "pqc": [os.path.join(dir_paths['mach_up_speed_dir'], "pqc"), os.path.join(dir_paths['mach_speed_results_dir'])], 
        "hybrid": [os.path.join(dir_paths['mach_up_speed_dir'], "hybrid"), os.path.join(dir_paths['mach_speed_results_dir'])],
    }

    # Set the pqc-var types dictionary so that both PQC and PQC-hybrid results can be processed
    pqc_type_vars.update({
        "up_results_path": [
            os.path.join(dir_paths['mach_up_results_dir'], "handshake_results", "pqc"), 
            os.path.join(dir_paths['mach_up_results_dir'], "handshake_results", "hybrid")
        ], 
    })

    # Ensure that the machine's up-results directory exists before continuing
    if not os.path.exists(dir_paths['mach_up_results_dir']):
        print(f"[ERROR] - Machine-ID ({machine_id}) up_results directory does not exist, please ensure the up_results directory is present before continuing")
        sys.exit(1)

    # Create the results directory for current machine and handle Machine-ID clashes
    handle_results_dir_creation(machine_id, dir_paths, replace_old_results)

    # Call the processing function and the average calculation methods for the current machine
    output_processing(num_runs, dir_paths, algs_dict, pqc_type_vars, col_headers, speed_headers)
    oqs_provider_avg.gen_pqc_avgs()
    oqs_provider_avg.gen_classic_avgs()
    oqs_provider_avg.gen_speed_avgs(speed_headers)

#------------------------------------------------------------------------------------------------------------------------------
def parse_oqs_provider(test_opts, replace_old_results):
    """ Main function for controlling the parsing of the OQS-Provider TLS handshake and speed results. This function
        is called from the main parsing control script and will call the necessary functions to parse the results """

    # Get test options and set test parameter vars
    machine_id = test_opts[0]
    num_runs = test_opts[1]
    root_dir = test_opts[2]

    # Setup script environment
    print(f"\nPreparing to Parse OQS-Provider Results:\n")
    dir_paths, algs_dict, pqc_type_vars, col_headers, speed_headers = setup_parse_env(root_dir)

    # Process the OQS-Provider results
    print(f"Parsing results...\n")
    process_tests(
        machine_id,
        num_runs,
        dir_paths,
        algs_dict,
        pqc_type_vars,
        col_headers,
        speed_headers,
        replace_old_results
    )