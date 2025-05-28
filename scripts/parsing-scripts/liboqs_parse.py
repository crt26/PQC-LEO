"""
Copyright (c) 2023-2025 Callum Turino
SPDX-License-Identifier: MIT

Liboqs result parsing script for PQC performance benchmarking.  
Parses raw memory and CPU speed results produced by the automated Liboqs test suite, processes them into  
clean, structured CSV files, and computes averaged results using the results_averager module.  
This script is called by the central parse_results.py controller and supports single-machine, multi-run setups.
"""

#-----------------------------------------------------------------------------------------------------------
import pandas as pd
import re
import os
import sys
import shutil
from results_averager import LiboqsResultAverager

# Declare the global variables
alg_operations = {'kem_operations': ["keygen", "encaps", "decaps"], 'sig_operations': ["keypair", "sign", "verify"]}
kem_algs = []
sig_algs = []
dir_paths = {}
num_runs = 0

#-----------------------------------------------------------------------------------------------------------
def setup_parse_env(root_dir):
    """ Function for setting up the environment for the Liboqs parsing script. 
        The function will set the various directory paths, read in the algorithm 
        lists and set the root directories. """

    global kem_algs, sig_algs, dir_paths

    # Ensure the root_dir path is correct before continuing
    if not os.path.isfile(os.path.join(root_dir, ".pqc_eval_dir_marker.tmp")):
        print("Project root directory path file not correct, the main parse_results.py file is not able to establish the correct path!!!")
        sys.exit(1)

    # Set the test results directory paths in central paths dictionary
    dir_paths['root_dir'] = root_dir
    dir_paths['results_dir'] = os.path.join(root_dir, "test-data", "results", "liboqs")
    dir_paths['up_results'] = os.path.join(root_dir, "test-data", "up-results", "liboqs")

    # Set the alg lists text filenames
    kem_algs_file = os.path.join(root_dir, "test-data", "alg-lists", "kem-algs.txt")
    sig_algs_file = os.path.join(root_dir, "test-data", "alg-lists", "sig-algs.txt")

    # Read in the algorithms from the KEM alg-list file
    with open(kem_algs_file, "r") as kem_file:
        for line in kem_file:
            kem_algs.append(line.strip())
    
    # Read in the algorithms from the sig alg-list file
    with open(sig_algs_file, "r") as alg_file:
        for line in alg_file:
            sig_algs.append(line.strip())

#-----------------------------------------------------------------------------------------------------------
def handle_results_dir_creation(machine_id):
    """ Function for handling the presence of older parsed results, 
        ensuring that the user is aware of the old results and can choose 
        how to handle them before the parsing continues. """

    # Check if there are any old parsed results for current Machine-ID and handle any clashes
    if os.path.exists(dir_paths["type_mem_dir"]) or os.path.exists(dir_paths["type_speed_dir"]):

        # Output the warning message to the terminal
        print(f"There are already parsed Liboqs testing results present for Machine-ID ({machine_id})\n")

        # Get the decision from user on how to handle old results before parsing continues
        while True:

            # Output the potential options and handle user choice
            print(f"\nFrom the following options, choose how would you like to handle the old Liboqs results:\n")
            print("Option 1 - Replace old parsed results with new ones")
            print("Option 2 - Exit parsing programme to move old results and rerun after (if you choose this option, please move the entire folder not just its contents)")
            print("Option 3 - Make parsing script programme wait until you have move files before continuing")
            user_choice = input("Enter option (1/2/3): ")

            if user_choice == "1":

                # Replace all old results and create a new empty directory to store the parsed results
                print(f"Removing old results directory for Machine-ID ({machine_id}) before continuing...")
                shutil.rmtree(dir_paths["results_dir"], f"machine-{machine_id}")
                print("Old results removed")

                os.makedirs(dir_paths["type_speed_dir"])
                os.makedirs(dir_paths["type_mem_dir"])
                break

            elif user_choice == "2":

                # Exit the script to allow the user to move old results before retrying
                print("Exiting parsing script...")
                exit()

            elif user_choice == "3":

                # Halt the script until the old results have been moved for current Machine-ID
                while True:

                    input(f"Halting parsing script so old parsed results for Machine-ID ({machine_id}) can be moved, press enter to continue")

                    # Check if the old results have been moved before continuing
                    if os.path.exists(dir_paths["type_mem_dir"]) or os.path.exists(dir_paths["type_speed_dir"]):
                        print(f"Old parsed results for Machine-ID ({machine_id}) still present!!!\n")

                    else:
                        print("Old results have been moved, now continuing with parsing script")
                        os.makedirs(dir_paths["type_speed_dir"])
                        os.makedirs(dir_paths["type_mem_dir"])
                        break
                
                break

            else:

                # Output warning message if the user input is not valid
                print("Incorrect value, please select (1/2/3)")

    else:

        # No old parsed results for current machine-id found, so creating new directories 
        os.makedirs(dir_paths["type_speed_dir"])
        os.makedirs(dir_paths["type_mem_dir"])

#-----------------------------------------------------------------------------------------------------------
def get_peak(mem_file, peak_metrics):
    """ Helper function for taking the passed massif.out file and getting 
        the peak memory metrics, returning the values to continue
        processing. The function comes from the run_mem.py script 
        found in OQS Profiling Project
        https://github.com/open-quantum-safe/profiling """

    # Get the max memory metric for current algorithm cryptographic operation
    with open(mem_file, "r") as lines:
        peak = -1
        for line in lines:
            if line.startswith(" Detailed snapshots: ["):
                match=re.search(r"\d+ \(peak\).*", line)
                if match:
                    peak = int(match.group(0).split()[0])      
            if (peak > 0):
                
                if line.startswith('{: >3d}'.format(peak)): # remove "," and print all numbers except first:
                    nl = line.replace(",", "")
                    peak_metrics = nl.split()
                    del peak_metrics[0]
                    return peak_metrics

#-----------------------------------------------------------------------------------------------------------
def pre_speed_processing():
    """ Function for preparing the speed up-result data to 
        by removing system information in the file, allowing for
        further processing in the script. """
    
    # Setup the destination directory in current machines up-results for pre-processed speed files
    if not os.path.exists(dir_paths['up_speed_dir']):
        os.makedirs(dir_paths['up_speed_dir'])
    else:
        shutil.rmtree(dir_paths["up_speed_dir"])
        os.makedirs(dir_paths['up_speed_dir'])

    # Setting the initial prefix variables for KEM and sig files
    kem_prefix = "test-kem-speed-"
    sig_prefix = "test-sig-speed-"

    # Pre-format the KEM and sig csv speed files to remove system information from file
    for run_count in range(1, num_runs+1):

        """ Pre-format the kem csv files """
        # Set the filename based on current run
        kem_pre_filename = kem_prefix + str(run_count) + ".csv"
        kem_filename = os.path.join(dir_paths["raw_speed_dir"], kem_pre_filename)

        # Read in the results file
        with open(kem_filename, 'r') as pre_file:
            rows = pre_file.readlines()

        # Get the header start index and format the file
        header_line_index = next(row_index for row_index, line in enumerate(rows) if line.startswith('Operation'))
        kem_pre_speed_df = pd.read_csv(kem_filename, skiprows=range(header_line_index), skipfooter=1, delimiter='|', engine='python')
        kem_pre_speed_df = kem_pre_speed_df.iloc[1:]

        # Write out the pre_formatted file to up-results speed dir
        speed_dest_dir = os.path.join(dir_paths["up_speed_dir"], kem_pre_filename)
        kem_pre_speed_df.to_csv(speed_dest_dir, index=False, sep="|")

        """ Pre-format the Digital Signature csv files """
        # Set the filename based on current run
        sig_pre_filename = sig_prefix + str(run_count) + ".csv"
        sig_filename = os.path.join(dir_paths["raw_speed_dir"], sig_pre_filename)

        # Read in the file
        with open(sig_filename, 'r') as pre_file:
            rows = pre_file.readlines()

        # Get the header start index and format the file
        header_line_index = next(i for i, line in enumerate(rows) if line.startswith('Operation'))
        sig_pre_speed_df = pd.read_csv(sig_filename, skiprows=range(header_line_index), skipfooter=1, delimiter='|', engine='python')
        sig_pre_speed_df = sig_pre_speed_df.iloc[1:]

        # Write out the pre-formatted file to up-results speed dir
        speed_dest_dir = os.path.join(dir_paths["up_speed_dir"], sig_pre_filename)
        sig_pre_speed_df.to_csv(speed_dest_dir, index=False, sep="|")

#-----------------------------------------------------------------------------------------------------------
def speed_processing():
    """ Function for processing the Liboqs CPU speed up-results and 
        exporting the data into a clean CSV format """

    # Set the filename prefix variables
    kem_prefix = "test-kem-speed-"
    sig_prefix = "test-sig-speed-"

    # Create the algorithm lists to insert into new header column
    new_col_kem = [alg for alg in kem_algs for _ in range(3)]
    new_col_sig = [alg for alg in sig_algs for _ in range(3)]
    
    # Read the original csv files and format them
    for file_count in range(1, num_runs+1):

        """ Format the KEM Files """
        # Load the KEM file into dataframe
        filename_kem_pre = kem_prefix + str(file_count) + ".csv"
        filename_kem_pre = os.path.join(dir_paths['up_speed_dir'], filename_kem_pre)
        temp_df = pd.read_csv(filename_kem_pre, delimiter="|", index_col=False)

        # Strip the trailing spaces and remove the algorithms from Operation column
        temp_df.columns = [col.strip() for col in temp_df.columns]
        temp_df = temp_df.loc[~temp_df['Operation'].str.strip().isin(kem_algs)]
        temp_df = temp_df.apply(lambda col: col.str.strip() if col.dtype == 'object' else col)

        # Insert the new algorithm column and output the formatted csv
        temp_df.insert(0, "Algorithm", new_col_kem)
        filename_kem = kem_prefix + str(file_count) + ".csv"
        filename_kem = os.path.join(dir_paths['type_speed_dir'], filename_kem)
        temp_df.to_csv(filename_kem, index=False)
        
        """ Formatting the Digital Signature Files """
        # Load the kem file into dataframe and strip the trailing spaces in columns headers
        filename_sig_pre = sig_prefix + str(file_count) + ".csv"
        filename_sig_pre = os.path.join(dir_paths['up_speed_dir'], filename_sig_pre)
        temp_df = pd.read_csv(filename_sig_pre, delimiter="|", index_col=False)

        # Strip the trailing spaces and remove the algorithms from the Operation column
        temp_df.columns = [col.strip() for col in temp_df.columns]
        temp_df = temp_df.loc[~temp_df['Operation'].str.strip().isin(sig_algs)]
        temp_df = temp_df.apply(lambda col: col.str.strip() if col.dtype == 'object' else col)

        # Insert the new algorithm column and output the formatted csv
        temp_df.insert(0, 'Algorithm', new_col_sig)
        filename_sig = sig_prefix + str(file_count) + ".csv"
        filename_sig = os.path.join(dir_paths['type_speed_dir'], filename_sig)
        temp_df.to_csv(filename_sig, index=False)

#-----------------------------------------------------------------------------------------------------------
def memory_processing():
    """ Function for taking in the memory up-results, processing,
        and outputting the results into a CSV format """

    # Set the un-parsed memory results directory variables
    kem_up_dir = os.path.join(dir_paths["up_mem_dir"], "kem-mem-metrics")
    sig_up_dir = os.path.join(dir_paths["up_mem_dir"], "sig-mem-metrics")

    # Declare the list variables used in memory processing
    new_row = []
    peak_metrics = []

    # Define the header column names for the dataframe
    fieldnames = ["Algorithm", "Operation", "intits", "maxBytes", "maxHeap", "extHeap", "maxStack"]
    
    # Loop through the number test runs specified
    for run_count in range(1, num_runs+1):

        # Create the dataframe to store memory metrics for the current run
        mem_results_df = pd.DataFrame(columns=fieldnames)

        # Loop through the KEM algorithms
        for kem_alg in kem_algs:

            # Loop through the cryptographic operations and add to the temp dataframe 
            for operation in range(0,3,1):

                # Parse the metrics and add the results to dataframe row
                kem_up_filename = kem_alg + "-" + str(operation) + "-" + str(run_count) + ".txt"
                kem_up_filepath = os.path.join(kem_up_dir, kem_up_filename)

                try:

                    # Create peak memory metrics list for current KEM algorithm and setup the new row
                    peak_metrics = get_peak(kem_up_filepath, peak_metrics)
                    new_row.extend([kem_alg, alg_operations['kem_operations'][operation]])

                    # Assign empty values for algorithm/operation row if no memory metrics were gathered
                    if peak_metrics is None:
                        peak_metrics = []
                        for _ in range(1, (len(fieldnames) - 2)):
                            peak_metrics.append("")
                    
                    # Fill in the row with algorithm/operation memory metrics before appending to dataframe
                    new_row.extend(peak_metrics)
                    mem_results_df.loc[len(mem_results_df)] = new_row

                    # Clear the metric and row lists
                    peak_metrics.clear()
                    new_row.clear()
                
                except Exception as e:
                    print(f"\nKEM algorithm memory parsing error, run - {run_count}")
                    print(f"error - {e}")
                    print(f"Filename {kem_up_filename}\n")
                    
        # Output the KEM csv file for this run
        kem_filename = "kem-mem-metrics-" + str(run_count) + ".csv"
        kem_filepath = os.path.join(dir_paths["type_mem_dir"], kem_filename)
        mem_results_df.to_csv(kem_filepath, index=False)

        # Loop through the digital signature algorithms
        for sig_alg in sig_algs:

            # Loop through the cryptographic operations and add to the temp dataframe 
            for operation in range(0,3,1):

                # Parse the metrics and add the results to dataframe row
                sig_up_filename = sig_alg + "-" + str(operation) + "-" + str(run_count) + ".txt"
                sig_up_filepath = os.path.join(sig_up_dir, sig_up_filename)

                try:

                    # Create peak memory metrics list for current sig algorithm and setup the new row
                    peak_metrics = get_peak(sig_up_filepath, peak_metrics)
                    new_row.extend((sig_alg, alg_operations['sig_operations'][operation]))

                    # Assign empty values for algorithm/operation row if no memory metrics were gathered
                    if peak_metrics is None:
                        peak_metrics = []
                        for _ in range(0, (len(fieldnames) - 2)):
                            peak_metrics.append("")
                        
                    # Fill in the row with algorithm/operation memory metrics before appending to dataframe
                    new_row.extend(peak_metrics)
                    mem_results_df.loc[len(mem_results_df)] = new_row

                    # Clear the metric and row lists
                    peak_metrics.clear()
                    new_row.clear()
                
                except Exception as e:
                    print(f"\nsig alg error, run - {run_count}")
                    print(f"error - {e}")
                    print(f"Filename {sig_up_filename}\n")

        # Output the digital signature csv file for this run
        sig_filename = "sig-mem-metrics-" + str(run_count) + ".csv"
        sig_filepath = os.path.join(dir_paths["type_mem_dir"], sig_filename)
        mem_results_df.to_csv(sig_filepath, index=False)

#-----------------------------------------------------------------------------------------------------------
def process_tests(machine_id):
    """ Function for parsing the results for a single or multiple machines 
        and stores them as csv files. Once up-results are processed
        averages are calculated for the results """
    
    global dir_paths

    # Create an instance of the Liboqs average generator class before processing results
    liboqs_avg = LiboqsResultAverager(dir_paths, kem_algs, sig_algs, num_runs, alg_operations)

    # Set the unparsed-directory paths in the central paths dictionary
    dir_paths['up_speed_dir'] = os.path.join(dir_paths['up_results'], f"machine-{str(machine_id)}", "speed-results")
    dir_paths['up_mem_dir'] = os.path.join(dir_paths['up_results'], f"machine-{str(machine_id)}", "mem-results")
    dir_paths['type_speed_dir'] = os.path.join(dir_paths['results_dir'], f"machine-{str(machine_id)}", "speed-results")
    dir_paths['type_mem_dir'] = os.path.join(dir_paths['results_dir'], f"machine-{str(machine_id)}", "mem-results")
    dir_paths['raw_speed_dir'] = os.path.join(dir_paths['up_results'], f"machine-{str(machine_id)}", "raw-speed-results")

    # Create the required directories and handling any clashes with previously parsed results
    handle_results_dir_creation(machine_id)

    # Parse the up-results for the specified Machine-ID
    pre_speed_processing()
    speed_processing()
    memory_processing()

    # Call the average generation methods for memory and CPU performance results
    liboqs_avg.avg_mem()
    liboqs_avg.avg_speed()

#-----------------------------------------------------------------------------------------------------------
def parse_liboqs(test_opts):
    """ Entrypoint for controlling the parsing of the Liboqs benchmarking results. This function
        is called from the main parsing control script and will call the necessary functions to parse the results """

    # Get the test options
    global num_runs
    machine_id = test_opts[0]
    num_runs = test_opts[1]

    # Setup the script environment
    print(f"\nPreparing to Parse Liboqs Results:\n")
    setup_parse_env(test_opts[2])

    # Process the results
    print("Parsing results... ")
    process_tests(machine_id)