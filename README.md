# snakemake-wrappers

This repository contains snakemake support scripts for using jams and common jams workflows. For configuring snakemake to run on the Leeds HPC clusters see: [snakemake-gridengine](https://github.com/drjbarker/snakemake-gridengine).

To use this repository run snakemake with

```
snakemake --wrapper-prefix="https://github.com/stonerlab/snakemake-wrappers/raw/"
```

## JAMS Snakemake wrapper

The wrapper allows easy execution of JAMS with some common parameters being configured as Snakemake params. And example input would be:

```
WRAPPER_PREFIX="https://github.com/stonerlab/snakemake-wrappers/raw"

rule test:
    input:
        "test.cfg"
    output: 
        "sim/{T}K/{prefix}_final.h5"
    log:
        "sim/{T}K/{prefix}.log"
    params:
        exe="jams-v2.3.1+3.97ac53b",
        name="{prefix}",
        temperature="{T}",
        alpha="0.1",
        settings="hamiltonians = ({ radius_cutoff = {r_cut}; });"
    wrapper:
        f"{WRAPPER_PREFIX}/0.1.4/phys/sim/jams"
```

Here we have used a variable `WRAPPER_PREFIX` instead of the command line argument `--wrapper-prefix` to make the work flow more portable.

The JAMS executable can be specified either as a path in `input` or a path or executable name in `params.exe`. If only the name is given then the wrapper will search PATH for the name. If neither `input` or `params.exe` work then it searches PATH for 'jams' anyway. 

All input files ending `.cfg` are treated as JAMS config files. The first input file ending `.h5` is treated as the initial spin input for the simulation.

The JAMS `--output` option will automatically be set by the path used for `output`. 

The terminal output of JAMS is written to the `log`. If no `log` is given then the output will appear on the terminal where Snakemake is running.

Valid `params` are:
- `exe`: JAMS executable
- `name`: name to use for simulation (and basename of output files) 
- `size`: a comma separated list inside a string of dimensions for the lattice (e.g. `size="32,32,32"`)
- `temperature`: JAMS option physics.temperature
- `alpha`: a comma separated list inside a string of alpha for each material (e.g. `alpha="0.1,0.1"`)
- `cmc_constraint_theta`: Constrained Monte Carlo theta constraint
- `cmc_constraint_phi`: Constrained Monte Carlo phi constraint
- `settings`: A string with any additional settings for JAMS.
