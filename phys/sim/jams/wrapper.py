__author__ = "Joseph Barker"
__copyright__ = "Copyright 2020, Joseph Barker"
__email__ = "j.barker@leeds.ac.uk"
__license__ = "MIT"

from shutil import which
import os.path

from snakemake.logging import logger
from snakemake.shell import shell
from snakemake.utils import makedirs

log = snakemake.log_fmt_shell(stdout=True, stderr=True)

def find_jams(filenames):
    for file in filenames:
        if os.path.basename(file).startswith("jams"):
            # check the file exists and is executable
            if os.access(exe, os.F_OK) and os.access(file, os.X_OK):
                return file
    return None

name = snakemake.params.get("name")
size = snakemake.params.get("size")
temperature = snakemake.params.get("temperature")
alpha = snakemake.params.get("alpha")
cmc_constraint_theta = snakemake.params.get("cmc_constraint_theta")
cmc_constraint_phi = snakemake.params.get("cmc_constraint_phi")
extra = snakemake.params.get("extra", "")

# set default output location to where snakemake is executing
output_path="."

command = []

# set the number of threads for OMP
command.append(f"export OMP_NUM_THREADS={snakemake.threads}; ")

# priority is:
# 1. snakemake.params.exe
# 2. snakemake.input
# 3. PATH

exe = snakemake.params.get("exe")
# check if the exe exists and is executable
if exe is not None:
    if not (os.access(exe, os.F_OK) and os.access(exe, os.X_OK)):
        # if we didn't find it as a path then we should search for it in PATH
        exe = which(exe)
        if exe is None:
            raise Exception(f"ERROR: jams executable {exe} (given in params) not found")
else:
    # snakemake.params.exe is empty so check snakemake.input
    exe = find_jams(snakemake.input)
    if exe is None:
        logger.warning(f'WARNING: jams executable not found from params or input')
        
    
# still didn't find anything so set to default name for PATH search
if exe is None:
    exe = 'jams'
    logger.warning(f'WARNING: searching PATH for "{exe}"')
    exe = which(exe)

# all our attempts to find the file have failed
if exe is None:
    raise Exception(f"ERROR: jams executable {exe} not found")

command.append(f" {exe} ")

# if we have specified output files then set output to their
# intended location
if len(snakemake.output) > 0:
    output_path = os.path.dirname(snakemake.output[0])
    makedirs(output_path)
    command.append(f" --output=\"{output_path}\" ")

if name is not None:
    command.append(f' --name=\"{name}\" ')

# Look through the input files for "*.cfg" files and append them.
# Note: We don't nessecarily have to have a config file, the whole config 
# could be given as strings
for file in snakemake.input:
    if file.endswith("cfg"):
        command.append(f" \"{file}\" ")

# If a h5 file is given as input, use the data for the initial 
# spins, only use the first h5 file specified. The painful series
# of escape characters is because we have to escape in both python
# and bash
for file in snakemake.input:
    if file.endswith("h5"):
        command.append(f" \"lattice : {{spins=\\\"{file}\\\";}};\" ")
        break

# Create config strings for common settings we use in parameter sweeps

if size is not None:
    command.append(
        f" \"lattice : {{ size = [{size}]; }}; \" ")
        
if temperature is not None:
    command.append(
        f" \"physics : {{temperature={temperature};}};\" ")

if alpha is not None:
    command.append(f" \" materials = (")
    alpha_list=alpha.split(",")
    for a in alpha_list:
        command.append(f" {{alpha = {a};}}, ")
    command.append(f" );\" ")

if cmc_constraint_theta is not None:
    command.append(
        f" \"solver : {{cmc_constraint_theta={cmc_constraint_theta};}};\" ")

if cmc_constraint_phi is not None:
    command.append(
        f" \"solver : {{cmc_constraint_phi={cmc_constraint_phi};}};\" ")

if extra is not None:
    command.append(f" \"{extra}\" ")

escape_brackets = lambda string : string.translate(
    str.maketrans({"{":  r"{{", "}":  r"}}"}))

# combine all of the parts of the command together and the
# {} braces which are needed in libconfig but must be escaped in 
# snakemake
shell(f"({escape_brackets(''.join(command))} {log})")
