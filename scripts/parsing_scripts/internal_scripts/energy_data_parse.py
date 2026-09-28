"""
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

Parsing script for PQC computational and TLS energy usage testing results. Parses raw computational energy, 
TLS handshake energy, and TLS speed energy results produced by the automated test scripts, and structures the 
data into clean CSV files for each machine and test run. This script is called by the central parse_results.py 
controller and supports single-machine, multi-run setups.

Unlike other parsing scripts in PQC-LEO, the energy usage parsing script expects the un-parsed result files to be
named in a specific format to allow the script to extract the relevant test metadata from the filename itself, 
which is then used to structure the parsed results.

The file naming format expected for each of the different types of energy usage testing results is as follows:

Computational Energy Usage Result - (test-type)_(alg-type)_(operation)_(alg-name)_(run-number).txt  
TLS Handshake Energy Usage Result - (test-type)_(session-id-type)_(signing-alg)@(kem-alg)_(run-number).txt
TLS Speed Energy Usage Result - (test-type)_(alg-type)_(operation)_(alg-name)_(run-number).txt
"""

#------------------------------------------------------------------------------------------------------------------------------
import pandas as pd
import re
import os
import sys
import shutil
import time
from internal_scripts.results_averager import EnergyAverager

#------------------------------------------------------------------------------------------------------------------------------
def handle_results_dir_creation(machine_id, dir_paths, replace_old_results):
    """ Function for handling the presence of older parsed results, ensuring that the user is aware of the old results 
        and can choose how to handle them before the parsing continues. """

    # Check if there are any old parsed results for the current Machine-ID and handle any clashes
    if os.path.exists(dir_paths['results_dir']):

        # Determine if the user needs prompted to handle the old results or if the --replace-old-results flag is set
        if replace_old_results:

            # Output the warning message about the old results
            print(f"[NOTICE] - The --replace-old-results flag has been set, replacing the old results for Machine-ID ({machine_id})\n")
            time.sleep(2)

            # Remove the old results directory automatically for current Machine-ID
            print(f"Removing old results directory for Machine-ID ({machine_id}) before continuing...\n")
            shutil.rmtree(dir_paths["results_dir"])

            # Create the new directories for parsed results
            os.makedirs(dir_paths["results_dir"])
        
        else:

            # Output the warning message to the terminal
            print(f"\n[WARNING] - There are already parsed energy usage results present for Machine-ID ({machine_id})")

            # Get the decision from the user on how to handle old results before parsing continues
            while True:

                # Output the potential options and handle user choice
                print(f"\nFrom the following options, choose how would you like to handle the old energy usage results:")
                print("Option 1 - Replace old parsed results with new ones")
                print("Option 2 - Exit parsing programme to move old results and rerun after (if you choose this option, please move the entire folder not just its contents)")
                print("Option 3 - Make parsing script programme wait until you have move files before continuing")
                user_choice = input("Enter option: ")

                if user_choice == "1":

                    # Replace all old results and create a new empty directory to store the parsed results
                    print(f"Removing old results directory for Machine-ID ({machine_id}) before continuing...\n")
                    shutil.rmtree(dir_paths["results_dir"])

                    # Create the new directories for parsed results
                    os.makedirs(dir_paths["results_dir"])
                    break

                elif user_choice == "2":

                    # Exit the script to allow the user to move old results before retrying
                    print("Exiting parsing script...")
                    exit()

                elif user_choice == "3":

                    # Halt the script until the old results have been moved for the current Machine-ID
                    while True:

                        # Wait for the user to indicate they have moved the old results before continuing
                        input(f"Halting parsing script so old parsed results for Machine-ID ({machine_id}) can be moved, press enter to continue")

                        # Check if the old results have been moved before continuing
                        if os.path.exists(dir_paths['results_dir']):
                            print(f"Old parsed results for Machine-ID ({machine_id}) still present!!!\n")

                        else:
                            print("Old results have been moved, now continuing with parsing script")
                            os.makedirs(dir_paths["results_dir"])
                            break
                    
                    break

                else:

                    # Output a warning message if the user input is not valid
                    print("Incorrect value, please select (1/2/3)")

    else:

        # No old parsed results for current machine-id found, so creating new directories 
        os.makedirs(dir_paths['results_dir'])

#------------------------------------------------------------------------------------------------------------------------------
def read_in_energy_data(result_filepath):
    """ Helper function for reading in the energy usage data from the passed result files, extracting the relevant values, 
        and returning it as a list of lists for further processing. """

    # Declare the extracted results list for storing the extracted data from the result file
    extracted_results = []

    # Open the target result file and loop through each line to process the data
    with open(result_filepath, "r") as lines: 
        for current_line in lines:

            # Declare the line data list to store the current line's result values
            line_data = []

            # Check if the line is empty and skip it
            if not current_line.strip():
                continue

            # Split the line's data into individual elements
            line_data_split = [part.strip() for part in current_line.split("|")]

            # Extract the values from each result data element
            for field in line_data_split:
                value_text = field.split(":", 1)[1]
                result_value = float("".join(char for char in value_text if char.isdigit() or char in ".-"))
                line_data.append(result_value)
            
            # Add the extracted line data to the extracted results list
            extracted_results.append(line_data)

    return extracted_results

#------------------------------------------------------------------------------------------------------------------------------
def process_baseline(baseline_file):
    """ Function for processing the baseline energy usage data from the provided baseline result file. The baseline data is 
        extracted and returned as a parsed dataframe. """
    
    # Define the baseline columns headers
    baseline_col_headers=["Voltage (V)", "Current (A)", "Power (W)", "mWh", "mAh", "Joules", "Elapsed Time (ms)"]

    # Define the all rows list to store baseline data and extract the baseline data
    extracted_results = read_in_energy_data(baseline_file)
    all_rows = [result_data for result_data in extracted_results]

    # Build and return baseline dataframe
    baseline_df = pd.DataFrame(all_rows, columns=baseline_col_headers)

    return baseline_df

#------------------------------------------------------------------------------------------------------------------------------
def process_comp_results(dir_paths, result_files, num_runs, eng_avgr):
    """ Function for processing the results from the computational energy usage testing, extracting the relevant data from 
        the result files, and organising the data into csv files for each test run. Refer to script header comment for 
        expected filename format of un-parsed result files. """
        
    # Define the column headers for the computational energy usage results
    main_col_headers = [
        "Algorithm Type", 
        "Run Number", 
        "Algorithm Name", 
        "Operation", 
        "Voltage (V)", 
        "Current (A)", 
        "Power (W)", 
        "mWh", 
        "mAh",
        "Joules",
        "Elapsed Time (ms)",
    ]
    
    # Define the all_rows dict to store the extracted data
    all_rows = []

    # Loop through the result files and process the data
    for filename in result_files:

        # Define the filename path so it can be read in
        result_filepath = os.path.join(dir_paths["up_results"], filename)

        # If the current file is the baseline, process it differently then move onto next file
        if "baseline" in filename:
            baseline_df = process_baseline(result_filepath)
            baseline_output_path = os.path.join(dir_paths["results_dir"], "comp_energy_usage_baseline.csv")
            baseline_df.to_csv(baseline_output_path, index=False)
            continue

        # Split the filename into fixed fields and account for algorithms with underscores
        filename_no_ext = filename.rsplit(".", 1)[0]
        parameter_fields = filename_no_ext.split("_")

        # Validate the expected comp filename structure
        if len(parameter_fields) < 5:
            print(f"[ERROR] - Bad computational energy result filename format: {filename}")
            sys.exit(1)

        # Extract the test metadata from the filename
        ext_test_params = {
            "alg-type": parameter_fields[1],
            "run-number": int(parameter_fields[-1]),
            "alg-name": "_".join(parameter_fields[3:-1]),
            "operation": parameter_fields[2]
        }

        # Read in the results for the current file
        extracted_results = read_in_energy_data(result_filepath)

        # Take the extracted data and add it to the main rows list
        for result_data in extracted_results:
            row_values = [ext_test_params[key] for key in ext_test_params.keys()]
            row_values.extend(result_data)
            all_rows.append(row_values)
        
    # Create the main dataframe using all of the parsed result data
    main_result_df = pd.DataFrame(all_rows, columns=main_col_headers)
    
    # Split the main dataframe into KEM and signature results and drop the algorithm type column
    kem_result_df = main_result_df[main_result_df["Algorithm Type"] == "kem"].copy()
    kem_result_df = kem_result_df.drop(columns=["Algorithm Type"])
    sig_result_df = main_result_df[main_result_df["Algorithm Type"] == "sig"].copy()
    sig_result_df = sig_result_df.drop(columns=["Algorithm Type"])

    # Sort the dataframes by alg-name, then run-number, then operation
    kem_result_df = kem_result_df.sort_values(
        by=["Algorithm Name", "Run Number", "Operation", "Elapsed Time (ms)"],
        ascending=[True, True, True, True],
        kind="stable"
    ).reset_index(drop=True)
    
    sig_result_df = sig_result_df.sort_values(
        by=["Algorithm Name", "Run Number", "Operation", "Elapsed Time (ms)"],
        ascending=[True, True, True, True],
        kind="stable"
    ).reset_index(drop=True)

    # Define the non-metric columns for the computational results
    non_metric_columns = ["Algorithm Name", "Operation"]
    
    # For the specified number of runs, create individual run dataframes and export them to a csv
    for current_run in range(1, num_runs+1):

        # Copy over all of the current run data and drop the run number column
        kem_run_df = kem_result_df[kem_result_df["Run Number"] == current_run].copy()
        kem_run_df = kem_run_df.drop(columns="Run Number")
        sig_run_df = sig_result_df[sig_result_df["Run Number"] == current_run].copy()
        sig_run_df = sig_run_df.drop(columns="Run Number")

        # Extract the current run dataframes to CSV files
        kem_result_filepath = os.path.join(dir_paths["results_dir"], f"comp_energy_usage_kem_{current_run}.csv")
        sig_result_filepath = os.path.join(dir_paths["results_dir"], f"comp_energy_usage_sig_{current_run}.csv")
        kem_run_df.to_csv(kem_result_filepath, index=False)
        sig_run_df.to_csv(sig_result_filepath, index=False)

        # Create the condensed sheet for the current run
        kem_run_condensed = eng_avgr.df_run_condenser(kem_run_df, non_metric_columns)
        sig_run_condensed = eng_avgr.df_run_condenser(sig_run_df, non_metric_columns)

        # Export the condensed dataframes to csv files
        kem_condensed_filepath = os.path.join(dir_paths["results_dir"], f"comp_energy_usage_kem_{current_run}_condensed.csv")
        sig_condensed_filepath = os.path.join(dir_paths["results_dir"], f"comp_energy_usage_sig_{current_run}_condensed.csv")
        kem_run_condensed.to_csv(kem_condensed_filepath, index=False)
        sig_run_condensed.to_csv(sig_condensed_filepath, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def process_tls_handshake_results(dir_paths, result_files, num_runs, eng_avgr):
    """ Function for processing the results from the TLS handshake energy usage testing, extracting the relevant data from 
        the result files, and organising the data into csv files for each test run. Refer to script header comment for 
        expected filename format of un-parsed result files. """
    
    # Define the main column headers for the dataframe and the all rows list
    main_col_headers = [
        "Signing Algorithm", 
        "KEM Algorithm", 
        "Session ID Reuse (*)", 
        "Run Number",
        "Voltage (V)", 
        "Current (A)", 
        "Power (W)", 
        "mWh", 
        "mAh",
        "Joules",
        "Elapsed Time (ms)",
    ]
    all_rows = []

    # Define the regex patterns for result classification
    hybrid_prefix_pattern = re.compile(r'^(rsa[0-9]+|p[0-9]+|x[0-9]+|bp[0-9]+|X25519|X448|SecP256r1|SecP384r1|SecP521r1|curveSM2)[a-zA-Z0-9_-]+$')
    classical_sig_pattern = re.compile(r'^(RSA_(?:[1-9][0-9]{3,4})|prime(?:192|224|256|384|521)v1|secp(?:192|224|256|384|521)r1)$')

    # Define the regex pattern for matching classical ciphers used in testing
    classical_cipher_pattern = re.compile(
        r'^TLS_(?:'
        r'AES_(?:128|192|256)_GCM(?:_SHA(?:256|384))?'
        r'|AES(?:128|192|256)_GCM(?:_SHA(?:256|384))?'
        r'|CHACHA20_POLY1305(?:_SHA256)?'
        r')$'
    )

    # Loop through the result files and process the data
    for filename in result_files:

        # Define the filename path so it can be read in
        result_filepath = os.path.join(dir_paths['up_results'], filename)

        # If the current file is the baseline, process it differently then move onto the next file
        if "baseline" in filename:
            baseline_df = process_baseline(result_filepath)
            baseline_output_path = os.path.join(dir_paths["results_dir"], "tls_handshake_energy_usage_baseline.csv")
            baseline_df.to_csv(baseline_output_path, index=False)
            continue

        # Remove the file extension and perform regex match on the filename to extract test params
        filename_no_extension = filename.rsplit(".", 1)[0]
        regex_matches = re.match(r"^tls_handshake_(new|reuse)_(.+?)@(.+)_(\d+)$", filename_no_extension)

        # Ensure that the regex match returned values before proceeding
        if not regex_matches:
            print(f"[ERROR] - Bad TLS handshake energy result filename format: {filename}")
            sys.exit(1)
            continue

        # Extract the test metadata from the regex match groups
        session_id_type = regex_matches.group(1)
        sig_alg = regex_matches.group(2)
        kem_alg = regex_matches.group(3)
        run_number = int(regex_matches.group(4))

        ext_test_params = {
            "signing-alg": sig_alg,
            "kem-alg": kem_alg,
            "session-id-reuse": "*" if session_id_type == "reuse" else "",
            "run-number": run_number
        }

        # Read in the results for the current file
        extracted_results = read_in_energy_data(result_filepath)

        # Take the extracted data and add it to the main rows list
        for result_data in extracted_results:
            row_values = [ext_test_params[key] for key in ext_test_params.keys()]
            row_values.extend(result_data)
            all_rows.append(row_values)

    # Create the main dataframe using all of the parsed result data
    main_result_df = pd.DataFrame(all_rows, columns=main_col_headers)

    # Sort the data frame by signing-alg, kem-alg, run-number
    main_result_df = main_result_df.sort_values(
        by=["Signing Algorithm", "KEM Algorithm", "Run Number", "Elapsed Time (ms)"],
        ascending=[True, True, True, True],
        kind="stable"
    ).reset_index(drop=True)

    # Determine rows for classical, hybrid-PQC, and PQC result combinations
    sig_is_classic = main_result_df["Signing Algorithm"].str.match(classical_sig_pattern, na=False)
    cipher_is_classic = main_result_df["KEM Algorithm"].str.match(classical_cipher_pattern, na=False)
    classic_mask = sig_is_classic & cipher_is_classic

    sig_is_hybrid = main_result_df["Signing Algorithm"].str.match(hybrid_prefix_pattern, na=False)
    kem_is_hybrid = main_result_df["KEM Algorithm"].str.match(hybrid_prefix_pattern, na=False)
    hybrid_mask = (sig_is_hybrid & kem_is_hybrid) & (~classic_mask)
    pqc_mask = ~(hybrid_mask | classic_mask)

    # Create separate dataframes for classic, PQC, and Hybrid-PQC testing combinations
    result_groups = {
        "classic": main_result_df[classic_mask].copy(),
        "pqc": main_result_df[pqc_mask].copy(),
        "hybrid_pqc": main_result_df[hybrid_mask].copy(),
    }

    # Define the sub result dirs in the dir_paths dict
    dir_paths["classic"] = os.path.join(dir_paths["results_dir"], "classic")
    dir_paths["pqc"] = os.path.join(dir_paths["results_dir"], "pqc")
    dir_paths["hybrid_pqc"] = os.path.join(dir_paths["results_dir"], "hybrid_pqc")

    # Build and sort the subgroup dataframes and export for each run
    for group_name, group_df in result_groups.items():

        # Create the sub-result directory for the current group
        dir_paths[group_name] = os.path.join(dir_paths["results_dir"], group_name)
        os.mkdir(dir_paths[group_name])

        # Organise and export the results for each of the test runs performed
        for current_run in range(1, num_runs+1):

            # Extract the results for the current run and drop the run-number column
            current_run_df = group_df[group_df["Run Number"] == current_run].copy()
            current_run_df = current_run_df.drop(columns=["Run Number"])

            # Rename the KEM Algorithm column to Ciphersuite for the classic group to match the expected output format
            if group_name == "classic":
                current_run_df = current_run_df.rename(columns={"KEM Algorithm": "Ciphersuite"})

            # Define the filepath for the results and export the data to a csv
            result_filepath = os.path.join(dir_paths[group_name], f"tls_handshake_{group_name}_{current_run}.csv")
            current_run_df.to_csv(result_filepath, index=False)

            # Define the non-metric columns for the current group to be used in the condensed sheet generation
            if group_name != "classic":
                non_metric_columns = ["Signing Algorithm", "KEM Algorithm", "Session ID Reuse (*)"]
            else:
                non_metric_columns = ["Signing Algorithm", "Ciphersuite", "Session ID Reuse (*)"]

            # Create the condensed sheet for the current run
            condensed_df = eng_avgr.df_run_condenser(current_run_df, non_metric_columns)

            # Export the condensed dataframe to a csv file
            condensed_filepath = os.path.join(dir_paths[group_name], f"tls_handshake_{group_name}_{current_run}_condensed.csv")
            condensed_df.to_csv(condensed_filepath, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def process_tls_speed_results(dir_paths, result_files, num_runs, eng_avgr):
    """ Function for processing the results from the TLS speed energy usage testing, extracting the relevant data from 
        the result files, and organising the data into csv files for each test run. Refer to script header comment 
        for expected filename format of un-parsed result files. """
    
    # Define the main column headers for the dataframe and the all rows list
    main_col_headers = [
        "Algorithm Type", 
        "Run Number", 
        "Algorithm Name", 
        "Operation", 
        "Voltage (V)", 
        "Current (A)", 
        "Power (W)", 
        "mWh", 
        "mAh",
        "Joules",
        "Elapsed Time (ms)",
    ]
    all_rows = []

    # Define the PQC-Hybrid algorithm prefix regex pattern
    hybrid_prefix_pattern = re.compile(r'^(rsa[0-9]+|p[0-9]+|x[0-9]+|bp[0-9]+|X25519|X448|SecP256r1|SecP384r1|SecP521r1|curveSM2)[a-zA-Z0-9_-]+$')

    # Loop through the result files and process the data
    for filename in result_files:

        # Define the filename path so it can be read in
        result_filepath = os.path.join(dir_paths["up_results"], filename)

        # If the current file is the baseline, process it differently then move onto next file
        if "baseline" in filename:
            baseline_df = process_baseline(result_filepath)
            baseline_output_path = os.path.join(dir_paths["results_dir"], "tls_speed_energy_usage_baseline.csv")
            baseline_df.to_csv(baseline_output_path, index=False)
            continue

        # Split the filename into fixed fields and account for algorithms with underscores
        filename_no_ext = filename.rsplit(".", 1)[0]
        parameter_fields = filename_no_ext.split("_")

        # Validate the expected tls speed result filename structure
        if len(parameter_fields) < 6 or parameter_fields[0] != "tls" or parameter_fields[1] != "speed":
            print(f"[ERROR] - Bad tls_speed filename format: {filename}")
            sys.exit(1)

        # Extract the test metadata from the filename
        ext_test_params = {
            "alg-type": parameter_fields[2],
            "run-number": int(parameter_fields[-1]),
            "alg-name": "_".join(parameter_fields[4:-1]),
            "operation": parameter_fields[3],
        }

        # Read in the results for the current file
        extracted_results = read_in_energy_data(result_filepath)

        # Take the extracted data and add it to the main rows list
        for result_data in extracted_results:
            row_values = [ext_test_params[key] for key in ext_test_params.keys()]
            row_values.extend(result_data)
            all_rows.append(row_values)
        
    # Create the main dataframe using all of the parsed result data
    main_result_df = pd.DataFrame(all_rows, columns=main_col_headers)

    # Separate the main dataframe into PQC/Hybrid-PQC only dataframes
    result_groups = {
        "pqc": main_result_df[~main_result_df["Algorithm Name"].str.match(hybrid_prefix_pattern, na=False)].copy(),
        "hybrid_pqc": main_result_df[main_result_df["Algorithm Name"].str.match(hybrid_prefix_pattern, na=False)].copy(),
    }

    # Build and sort the subgroup dataframes and export for each run
    for alg_group in result_groups.keys():
        for alg_type in ("kem", "sig"):
            
            # Create the current alg_group/alg_type dataframe and drop algorithm type column
            sub_group_df = result_groups[alg_group][result_groups[alg_group]["Algorithm Type"] == alg_type].copy()
            sub_group_df = sub_group_df.drop(columns=["Algorithm Type"])

            # Sort the dataframe by alg-name, then run-number, then operation
            sub_group_df = sub_group_df.sort_values(
                by=["Algorithm Name", "Run Number", "Operation"],
                ascending=[True, True, True],
                kind="stable"
            ).reset_index(drop=True)

            # For the specified number of runs, create individual run dataframes and export it to csv
            for current_run in range(1, num_runs+1):

                # Copy over all of the current run data and drop the run number column
                current_run_df = sub_group_df[sub_group_df["Run Number"] == current_run].copy()
                current_run_df = current_run_df.drop(columns=["Run Number"])

                # Define the filepath for the results and export the data to a csv
                result_filepath = os.path.join(dir_paths["results_dir"], f"tls_speed_{alg_group}_{alg_type}_{current_run}.csv")
                current_run_df.to_csv(result_filepath, index=False)

                # Create the condensed sheet for the current run
                condensed_df = eng_avgr.df_run_condenser(current_run_df, ["Algorithm Name", "Operation"])

                # Define the filepath for the condensed results and export the data to a csv
                condensed_filepath = os.path.join(dir_paths["results_dir"], f"tls_speed_{alg_group}_{alg_type}_{current_run}_condensed.csv")
                condensed_df.to_csv(condensed_filepath, index=False)

#------------------------------------------------------------------------------------------------------------------------------
def process_test(dir_paths, num_runs):
    """ Function for controlling the processing of the energy usage test results, determining which type of testing 
        was performed based on the result filenames, and calling the relevant processing function for the test type. 
        Refer to script header comment for expected filename format of un-parsed result files. """

    # Read in the result filenames and sort them
    test_results = []
    for filename in os.listdir(dir_paths['up_results']):
        if os.path.isfile(os.path.join(dir_paths['up_results'], filename)):
            test_results.append(filename)
    test_results.sort()

    # Declare an instance of the result average class
    eng_avgr = EnergyAverager(dir_paths, num_runs)

    # Determine which type of testing was performed
    example_file = test_results[0]
    if "comp" in example_file:
        process_comp_results(dir_paths, test_results, num_runs, eng_avgr)

    elif "tls_handshake" in example_file:
        process_tls_handshake_results(dir_paths, test_results, num_runs, eng_avgr)

    elif "tls_speed" in example_file:
        process_tls_speed_results(dir_paths, test_results, num_runs, eng_avgr)

    else:
        print(f"[ERROR] - Unsupported test type was extracted from result filename - {example_file}")
        sys.exit(1)

#------------------------------------------------------------------------------------------------------------------------------
def parse_energy_data(test_opts, replace_old_results):
    """ Entrypoint for parsing energy usage testing results. It handles the initial setup for the parsing process, extracting 
        the relevant test options, defines the relevant directory paths, and then calls the main processing function to handle 
        the parsing of the results. """
    
    # Get the test options from the passed dict
    machine_id = test_opts["machine_id"]
    num_runs = test_opts["total_runs"]
    test_type = test_opts["eng_test_type"]
    root_dir = test_opts["root_dir"]

    # Declare the dir paths dictionary
    dir_paths = {}

    # Ensure the root_dir path is correct before continuing
    if not os.path.isfile(os.path.join(root_dir, ".pqc_leo_dir_marker.tmp")):
        print("Project root directory path file not correct, the main parse_results.py file is not able to establish the correct path!!!")
        sys.exit(1)

    # Set the test results directory paths in central paths dictionary
    dir_paths['root_dir'] = root_dir
    dir_paths['results_dir'] = os.path.join(root_dir, "test_data", "results", "energy_test_results", test_type, f"machine_{machine_id}")
    dir_paths['up_results'] = os.path.join(root_dir, "test_data", "up_results", "energy_test_results", test_type, f"machine_{machine_id}")

    # Ensure that the machine's up-results directory exists before continuing
    if not os.path.exists(dir_paths['up_results']):
        print(f"[ERROR] - Machine-ID ({machine_id}) up_results directory does not exist, please ensure the up-results directory is present before continuing")
        sys.exit(1)

    # Handle the target parsed results directory creation and process the results
    handle_results_dir_creation(machine_id, dir_paths, replace_old_results)
    process_test(dir_paths, num_runs)
