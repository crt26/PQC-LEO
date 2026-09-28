"""
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

Parsing script for PQC computational and TLS energy usage testing results. Parses raw computational energy,
TLS handshake energy, and TLS operations energy results produced by the automated test scripts, and structures the
data into clean CSV files for each machine and test run. This script is called by the central parse_results.py 
controller and supports single-machine, multi-run setups.

Unlike other parsing scripts in PQC-LEO, the energy usage parsing script expects the un-parsed result files to be
named in a specific format to allow the script to extract the relevant test metadata from the filename itself, 
which is then used to structure the parsed results.

The file naming format expected for each of the different types of energy usage testing results is as follows:

Computational Energy Usage Result - comp_(alg-type)_(operation)_(alg-name)_(run-number).txt
PQC/Hybrid TLS Handshake Energy Result - tls_handshake_(session-id-type)_(signing-alg)@(kem-alg)_(run-number).txt
Classic TLS Handshake Energy Result - tls_handshake_(session-id-type)_(signing-alg)@(key-exchange-group)@(ciphersuite)_(run-number).txt
TLS Operations Energy Usage Result - tls_operations_(alg-type)_(operation)_(alg-name)_(run-number).txt
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

    # Define the core column header lists for the TLS handshake results
    metric_col_headers = [
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
    pqc_based_col_headers = ["Signing Algorithm", "KEM Algorithm", *metric_col_headers]
    classic_based_alg_col_headers = ["Signing Algorithm", "Key Exchange Group", "Ciphersuite", *metric_col_headers]

    # Define the dict for storing the extracted results for each testing category
    all_results = {
        "pqc": [],
        "hybrid_pqc": [],
        "classic": [],
    }

    # Define the regex pattern for matching Hybrid-PQC algorithms
    hybrid_prefix_pattern = re.compile(r'^(rsa[0-9]+|p[0-9]+|x[0-9]+|bp[0-9]+|X25519|X448|SecP256r1|SecP384r1|SecP521r1|curveSM2)[a-zA-Z0-9_-]+$')

    # Loop through the result files and process the data
    for filename in result_files:

        # Define the filepath for the current result file
        result_filepath = os.path.join(dir_paths["up_results"], filename)

        # If the current file is the baseline, process it differently then move onto the next file
        if "baseline" in filename:
            baseline_df = process_baseline(result_filepath)
            baseline_output_path = os.path.join(dir_paths["results_dir"], "tls_handshake_energy_usage_baseline.csv")
            baseline_df.to_csv(baseline_output_path, index=False)
            continue

        # Remove the file extension and perform regex match on the filename to extract test params
        filename_no_extension = filename.rsplit(".", 1)[0]
        regex_matches = re.fullmatch(r"tls_handshake_(new|reuse)_(.+)_(\d+)", filename_no_extension)

        # Ensure that the regex match returned values before proceeding
        if not regex_matches:
            print(f"[ERROR] - Bad TLS handshake energy result filename format: {filename}")
            sys.exit(1)

        # Extract the test parameters from the regex match groups
        session_id_type = regex_matches.group(1)
        session_id_type = "*" if session_id_type == "reuse" else ""
        algorithm_fields = regex_matches.group(2).split("@")
        run_number = int(regex_matches.group(3))

        # Ensure that none of the extracted algorithm fields are empty before proceeding
        if any(not field for field in algorithm_fields):
            print(f"[ERROR] - Bad TLS handshake energy result filename format: {filename}")
            sys.exit(1)

        # Set the default values for the test type flags
        test_type = None

        # Get the signing, kem/key exchange, and ciphersuite algorithm names from the algorithm fields
        if len(algorithm_fields) == 2:

            # Extract the signing and KEM/algorithm names
            sig_alg = algorithm_fields[0]
            kem_alg = algorithm_fields[1]
            
        elif  len(algorithm_fields) == 3:

            # Extract the signing, key exchange, and ciphersuite algorithm names
            sig_alg = algorithm_fields[0]
            key_exchange_group = algorithm_fields[1]
            cipher_suite = algorithm_fields[2]

            # Set the classic test flag to true since the filename contains a ciphersuite
            test_type = "classic"

        else:
            print(f"[ERROR] - Bad TLS handshake energy result filename format: {filename}")
            sys.exit(1)

        # If not already determined to be a classic test, check if it is PQC or Hybrid-PQC based on the signing and kem algorithm names
        if test_type != "classic":

            # Check if the signing and KEM algorithm names match the Hybrid-PQC regex pattern
            sig_is_hybrid = bool(hybrid_prefix_pattern.fullmatch(sig_alg))
            kem_is_hybrid = bool(hybrid_prefix_pattern.fullmatch(kem_alg))

            # Ensure there is no mismatch between the signing and KEM algorithm types being hybrid or non-hybrid
            if sig_is_hybrid != kem_is_hybrid:
                print(f"[ERROR] - Mismatch between signing and KEM algorithm types for TLS handshake energy result filename: {filename}")
                sys.exit(1)

            # Determine the test type based on the signing and KEM algorithm names
            test_type = "hybrid_pqc" if sig_is_hybrid and kem_is_hybrid else "pqc"

        # Set the test parameters dictionary for the current result file based on test type
        if test_type in ["pqc", "hybrid_pqc"]:
            ext_test_params = {
                "signing-alg": sig_alg,
                "kem-alg": kem_alg,
                "session-id-type": session_id_type,
                "run-number": run_number
            }

        elif test_type == "classic":
            ext_test_params = {
                "signing-alg": sig_alg,
                "key-exchange-group": key_exchange_group,
                "ciphersuite": cipher_suite,
                "session-id-type": session_id_type,
                "run-number": run_number
            }

        else:
            print(f"[ERROR] - Test type could not be determined for TLS handshake energy result filename: {filename}")
            sys.exit(1)
        
        # Extract the energy usage data from the result file
        extracted_results = read_in_energy_data(result_filepath)

        # Take the extracted data and add it to the relevant results list based on test type
        for result_data in extracted_results:
            row_values = [ext_test_params[key] for key in ext_test_params.keys()]
            row_values.extend(result_data)
            all_results[test_type].append(row_values)

    # Loop through each test type and handle result processing
    for test_group in all_results.keys():

        # Create the result dataframe for the current test group and define the algorithm columns for the test type
        if test_group in ["pqc", "hybrid_pqc"]:
            group_df = pd.DataFrame(all_results[test_group], columns=pqc_based_col_headers)
            alg_columns = pqc_based_col_headers[0:2]

        elif test_group == "classic":
            group_df = pd.DataFrame(all_results[test_group], columns=classic_based_alg_col_headers)
            alg_columns = classic_based_alg_col_headers[0:3]

        # Define the sort columns and non-metric columns for the current test group
        sort_columns = [*alg_columns, "Run Number", "Session ID Reuse (*)"]
        non_metric_columns = [*alg_columns, "Session ID Reuse (*)"]

        # Sort the dataframe by the relevant columns and reset the index
        group_df = group_df.sort_values(
            by=sort_columns,
            kind="stable"
        ).reset_index(drop=True)

        # Define the result subdirectory path and create it
        dir_paths[f"{test_group}_subdir"] = os.path.join(dir_paths["results_dir"], test_group)
        os.mkdir(dir_paths[f"{test_group}_subdir"])

        # Organise and export the results for each of the test runs performed
        for current_run in range(1, num_runs+1):

            # Extract the results for the current run and drop the run-number column
            current_run_df = group_df[group_df["Run Number"] == current_run].copy()
            current_run_df = current_run_df.drop(columns=["Run Number"])

            # Define the filepath for the results and export the data to a csv
            result_filepath = os.path.join(dir_paths[f"{test_group}_subdir"], f"tls_handshake_{test_group}_{current_run}.csv")
            current_run_df.to_csv(result_filepath, index=False)

            # Create the condensed sheet for the current run
            condensed_df = eng_avgr.df_run_condenser(current_run_df, non_metric_columns)

            # Export the condensed dataframe to a csv file
            condensed_filepath = os.path.join(dir_paths[f"{test_group}_subdir"], f"tls_handshake_{test_group}_{current_run}_condensed.csv")
            condensed_df.to_csv(condensed_filepath, index=False)
        
#------------------------------------------------------------------------------------------------------------------------------
def process_tls_operations_results(dir_paths, result_files, num_runs, eng_avgr):
    """ Function for processing the results from the TLS operations energy usage testing, extracting the relevant data from
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

    # Define the PQC-Hybrid algorithm regex matching pattern
    hybrid_pattern = re.compile(
        r"^(?:"
        r"(?:rsa[0-9]+|p[0-9]+|x[0-9]+|bp[0-9]+)"
        r"_[A-Za-z0-9_-]+"
        r"|"
        r"(?:X25519|X448|SecP256r1|SecP384r1|SecP521r1|curveSM2)"
        r"[A-Za-z][A-Za-z0-9_-]*"
        r")$"
    )

    # Define the classical algorithm regex matching pattern
    classic_pattern = re.compile(
        r"^(?:"
        r"RSA(?:-PSS)?_(?:2048|3072|4096)"
        r"|prime256v1"
        r"|secp(?:256|384|521)r1"
        r"|ed(?:25519|448)"
        r"|x(?:25519|448)"
        r"|brainpoolP(?:256|384|512)r1(?:tls13)?"
        r")$"
    )

    # Loop through the result files and process the data
    for filename in result_files:

        # Define the filename path so it can be read in
        result_filepath = os.path.join(dir_paths["up_results"], filename)

        # If the current file is the baseline, process it differently then move onto next file
        if "baseline" in filename:
            baseline_df = process_baseline(result_filepath)
            baseline_output_path = os.path.join(dir_paths["results_dir"], "tls_operations_energy_usage_baseline.csv")
            baseline_df.to_csv(baseline_output_path, index=False)
            continue

        # Split the filename into fixed fields and account for algorithms with underscores
        filename_no_ext = filename.rsplit(".", 1)[0]
        parameter_fields = filename_no_ext.split("_")

        # Validate the expected TLS operations result filename structure
        if len(parameter_fields) < 6 or parameter_fields[0] != "tls" or parameter_fields[1] != "operations":
            print(f"[ERROR] - Bad tls_operations filename format: {filename}")
            sys.exit(1)

        # Extract the test metadata from the filename
        ext_test_params = {
            "alg-type": parameter_fields[2],
            "run-number": int(parameter_fields[-1]),
            "alg-name": "_".join(parameter_fields[4:-1]),
            "operation": parameter_fields[3],
        }

        # If the alg-type is key-exchange, replace the dash with underscore
        if ext_test_params["alg-type"] == "key-exchange":
            ext_test_params["alg-type"] = "key_exchange"

        # Read in the results for the current file
        extracted_results = read_in_energy_data(result_filepath)

        # Take the extracted data and add it to the main rows list
        for result_data in extracted_results:
            row_values = [ext_test_params[key] for key in ext_test_params.keys()]
            row_values.extend(result_data)
            all_rows.append(row_values)
        
    # Create the main dataframe using all of the parsed result data
    main_result_df = pd.DataFrame(all_rows, columns=main_col_headers)

    # Using the Hybrid-PQC and classical matching patterns, define dataframe masks for the two alg groups
    hybrid_df_mask = main_result_df["Algorithm Name"].str.fullmatch(hybrid_pattern, na=False)
    classic_df_mask = main_result_df["Algorithm Name"].str.fullmatch(classic_pattern, na=False)

    # Separate the main dataframe into PQC/Hybrid-PQC/classic only dataframes and define the relevant parameters for each group
    result_groups = {
        "pqc": {
            "dataframe": main_result_df[~hybrid_df_mask & ~classic_df_mask].copy(),
            "alg_types": ["kem", "sig"],
            "output_subdir": "pqc",
        },
        "hybrid_pqc": {
            "dataframe": main_result_df[hybrid_df_mask].copy(),
            "alg_types": ["kem", "sig"],
            "output_subdir": "hybrid",
        },
        "classic": {
            "dataframe": main_result_df[classic_df_mask].copy(),
            "alg_types": ["sig", "key_exchange"],
            "output_subdir": "classic",
        },
    }

    # Build and sort the subgroup dataframes and export for each run
    for alg_group, group_config in result_groups.items():

        # Define the group dataframe, its algorithm types, and create its output subdirectory
        group_df = group_config["dataframe"]
        group_alg_types = group_config["alg_types"]
        group_output_dir = os.path.join(dir_paths["results_dir"], group_config["output_subdir"])
        os.makedirs(group_output_dir, exist_ok=True)

        # For each alg type, create and export the sub-group results
        for alg_type in group_alg_types:

            # Create the current alg_group/alg_type dataframe and drop algorithm type column
            sub_group_df = group_df[group_df["Algorithm Type"] == alg_type].copy()
            sub_group_df = sub_group_df.drop(columns=["Algorithm Type"])

            # Sort the dataframe by alg-name, then run-number, then operation
            sub_group_df = sub_group_df.sort_values(
                by=["Algorithm Name", "Run Number", "Operation"],
                ascending=[True, True, True],
                kind="stable",
            ).reset_index(drop=True)

            # For the specified number of runs, create individual run dataframes and export it to csv
            for current_run in range(1, num_runs + 1):

                # Copy over all of the current run data and drop the run number column
                current_run_df = sub_group_df[sub_group_df["Run Number"] == current_run].copy()
                current_run_df = current_run_df.drop(columns=["Run Number"])

                # Define the filepath for the results and export the data to a csv
                result_filepath = os.path.join(group_output_dir, f"tls_operations_{alg_group}_{alg_type}_{current_run}.csv")
                current_run_df.to_csv(result_filepath, index=False)

                # Create the condensed sheet for the current run
                condensed_df = eng_avgr.df_run_condenser(current_run_df, ["Algorithm Name", "Operation"])

                # Define the filepath for the condensed results and export the data to a csv
                condensed_filepath = os.path.join(group_output_dir, f"tls_operations_{alg_group}_{alg_type}_{current_run}_condensed.csv")
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

    elif "tls_operations" in example_file:
        process_tls_operations_results(dir_paths, test_results, num_runs, eng_avgr)

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
