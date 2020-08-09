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
        