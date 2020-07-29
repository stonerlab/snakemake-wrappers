localrules: build_jams

rule build_jams:
    '''
    Build jams from a given filename

    Only the commit hash is used by the build script. We pull the build 
    script itself from the latest version of jams to avoid carrying
    the script around and to ensure it is up-to-date.

    '''
    output:
        "{relpath}jams-{version}+{commits}.{hash}"
    shell:
        """
        DIR="$(pwd)"
        TMP_DIR=$(mktemp -d)
        cd $TMP_DIR && git clone -n https://github.com/stonerlab/jams.git --depth 1 &> /dev/null
        cd jams && git checkout HEAD scripts/build-jams.sh &> /dev/null 
        scripts/build-jams.sh -c {wildcards.hash} && cp jams-{wildcards.version}+{wildcards.commits}.{wildcards.hash} $DIR/{wildcards.relpath}
        """

def find_jams(filenames):
    for file in filenames:
        if os.path.basename(file).startswith("jams"):
            # check the file exists and is executable
            if os.path.isfile(file) and os.access(file, os.X_OK):
                return file
    raise Exception("jams executable not found")

def exec_jams(input, output, params=None, prefix=None, log=None, exe=None, threads=1):
    '''
    Executes jams infering options from input, output and params

    - The first input file containing "jams" which exists and is executable will be used as the jams binary
    - Any input file "*.cfg" will be treated as a JAMS config file
    - The first input file "*.h5" will be treated as data for the initial spin configuration
    - The output directory will be deduced from the path of the first output file
    - params can be used for some jams settings to automatically generate config strings:
        * temperature -> jams setting 'physics.temperature'
        * t_max -> jams setting 'solver.t_max' for dynamical solvers
        * max_steps -> jams setting 'solver.max_steps' for Monte Carlo solvers
        * cmc_constraint_theta -> jams setting 'solver.cmc_constraint_theta' for Constrained Monte Carlo
        * cmc_constraint_phi -> jams setting 'solver.cmc_constraint_phi' for Constrained Monte Carlo

    '''
    # set default output location to where snakemake is executing
    output_path="."

    command = []

    # set the number of threads for OMP
    command.append(f"export OMP_NUM_THREADS={threads}; ")

    if exe is None:
        # look for jams executable in the list of input files
        exe = find_jams(input)
    else:
        # check if the manually given exe can be found
        if not os.path.isfile(exe):
            raise Exception(f"jams executable {exe} not found")

    command.append(f" {exe} ")

    # if we have specified output files then set output to their
    # intended location
    if len(output) > 0:
        output_path = os.path.dirname(output[0])
    
    command.append(f" --output=\"{output_path}\" ")

    if prefix is not None:
        command.append(" --name {prefix} ")

    # Look through the input files for "*.cfg" files and append them.
    # Note: We don't nessecarily have to have a config file, the whole config 
    # could be given as strings
    for file in input:
        if file.endswith("cfg"):
            command.append(f" \"{file}\" ")

    # If a h5 file is given as input, use the data for the initial 
    # spins, only use the first h5 file specified. The painful series
    # of escape characters is because we have to escape in both python
    # and bash
    for file in input:
        if file.endswith("h5"):
            command.append(f" \"lattice : {{spins=\\\"{file}\\\";}};\" ")
            break

    # Create config strings for common settings we use in parameter sweeps
    if hasattr(params, "temperature"):
        command.append(
            f" \"physics : {{temperature={params.temperature};}};\" ")

    if hasattr(params, "t_max"):
        command.append(
            f" \"solver : {{t_max={params.t_max};}};\" ")

    if hasattr(params, "max_steps"):
        command.append(
            f" \"solver : {{max_steps={params.max_steps};}};\" ")

    if hasattr(params, "cmc_constraint_theta"):
        command.append(
            f" \"solver : {{cmc_constraint_theta={params.cmc_constraint_theta};}};\" ")

    if hasattr(params, "cmc_constraint_phi"):
        command.append(
            f" \"solver : {{cmc_constraint_phi={params.cmc_constraint_phi};}};\" ")

    if log is None:
        log = f"{output_path}/jams.log"

    # set cout and cerr output from jams to be appended to the log
    command.append(f" >> \"{log}\" 2>&1")

    escape_brackets = lambda string : string.translate(
        str.maketrans({"{":  r"{{", "}":  r"}}"}))

    # combine all of the parts of the command together and the
    # {} braces which are needed in libconfig but must be escaped in 
    # snakemake
    shell(escape_brackets(''.join(command)))
