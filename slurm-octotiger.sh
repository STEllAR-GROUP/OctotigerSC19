#!/bin/bash

#   Copyright (c) 2019 John Biddiscombe
#
#   Distributed under the Boost Software License, Version 1.0. (See accompanying
#   file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Generates many slurm scripts to execute some code with different parameters
# When executed - this script:
# Creates a subdir for each job, puts an sbatch job submission file in each subdir
# Create a run_jobs.sh script in the top level dir that will submit all jobs
# Creates a cancel_jobs script that cancels jobs run by run_jobs script

# If the job script is run twice, then any directories/jobs that exist
# from the previous execution will be skipped. Therefore if
# a test fails with one parameter combination, but passes on others
# the failing test dir can be deleted, the script re-run and only the
# failing test will be regenerated and put into the run_jobs.sh script

function write_script
{
JOB_NAME=$(printf 'octotiger-N%04d-L%05d-t%02d-%s' ${NODES} ${LEVEL} ${THREADS_PERTASK} ${PARCELTYPE})
DIR_NAME=$(printf 'octotiger-N%04d-L%05d-t%02d-%s' ${NODES} ${LEVEL} ${THREADS_PERTASK} ${PARCELTYPE})
TASKS_PER_NODE=1

if [[ -d "$DIR_NAME" && -f "$DIR_NAME/slurm.out" ]]; then
  # Directory already exists, skip generation of this job
  echo "Exists already : Skipping $DIR_NAME"
  return 1
fi

echo "Creating job $DIR_NAME"

mkdir -p $DIR_NAME
cp ${FILES_TO_COPY} $DIR_NAME

cat << _EOF_ > ${DIR_NAME}/submit-job.bash
#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --output=slurm.out
#SBATCH --error=slurm.err
#SBATCH --nodes=${NODES}
#SBATCH --time=${TIME}
#SBATCH --exclusive
#SBATCH --distribution=cyclic
#SBATCH --constraint=gpu
#SBATCH --partition=${QUEUE}
##SBATCH --account=d69

#======START=====
module load slurm
# slurm broadcast file copy
echo "$(date +%H:%M:%S) Copying restart file to /tmp"
${BCAST}

# slurm launch command
echo "$(date +%H:%M:%S) launching octotiger"
srun -n $[${PROCESSES_PERNODE} * $NODES] ${PERF} ${EXECUTABLE1} ${PROGRAM_PARAMS}
_EOF_

# make the job script executable
chmod 775 ${DIR_NAME}/submit-job.bash

# create a script that launches the job and adds the jobid to a cancel jobs script
echo "cd ${DIR_NAME}; JOB=\$(sbatch submit-job.bash) ; echo \"\$JOB\" ; echo \"\$JOB\" | sed 's/Submitted batch job/scancel/g' >> \$BASEDIR/cancel_jobs.bash; cd \$BASEDIR" >> run_jobs.bash

}

# get the path to this generate script, works for most cases
pushd `dirname $0` > /dev/null
BASEDIR=`pwd`
popd > /dev/null
echo "Generating jobs using base directory $BASEDIR"

# Create another script to submit all generated jobs to the scheduler
echo "#!/bin/bash" > run_jobs.bash
echo "BASEDIR=$BASEDIR" >> run_jobs.bash
echo "cd $BASEDIR" >> run_jobs.bash
chmod 775 run_jobs.bash

##############################################
# Edit the stuff below this line, try to leave
# the stuff above unchanged
##############################################

MY_ROOT="/scratch/snx3000/biddisco/build/octo"

MPIEXEC=""
EXECUTABLE1="$MY_ROOT/octotiger"
RESTART="$MY_ROOT/scripts/restart.13.silo"
RESTART_LEVEL=13
TIME="00:45:00"
PROCESSES_PERNODE=1
FILES_TO_COPY="v1309.ini agas-pfx-counters.cfg"

# Loop through all the parameter combinations generating jobs for each

for PARCELTYPE in "libfabric"
do
  for LEVEL in 14 15 16
  do
    if [ "$LEVEL" == "14" ]; then
      N1=0     # 2^0  = 1
      N2=5     # 2^5  = 32
    elif [ "$LEVEL" == 15 ]; then
      N1=4     # 2^5  = 32
      N2=10    # 2^10 = 1024
    elif [ "$LEVEL" == 16 ]; then
      N1=8     # 2^9  = 512
      N2=12    # 2^12 = 4096
    fi

    for NPOWER in $(seq $N1 1 $N2)
    do
      NODES=$((2 ** $NPOWER))

      if [ "$NODES" == "4096" ]; then
        QUEUE=large
      else
        QUEUE=normal
      fi

      TCP_ENABLE="-Ihpx.parcel.tcp.enable=0"
      MPI_ENABLE="-Ihpx.parcel.mpi.enable=0"
      FAB_ENABLE="-Ihpx.parcel.libfabric.enable=0"

      if [ "$PARCELTYPE" == "tcp" ]; then
        TCP_ENABLE="-Ihpx.parcel.tcp.enable=1"
      elif [ "$PARCELTYPE" == "mpi" ]; then
        MPI_ENABLE="-Ihpx.parcel.mpi.enable=1"
      elif [ "$PARCELTYPE" == "libfabric" ]; then
        FAB_ENABLE="-Ihpx.parcel.libfabric.enable=1 -Ihpx.parcel.bootstrap=libfabric -Ihpx.parcel.message_handlers=0"
      fi

      # change these if inappropriate
      HPX_ARGS="--hpx:ini=hpx.stacks.use_guard_pages=0 --hpx:bind=numa-balanced --hpx:options-file=agas-pfx-counters.cfg"

      # commment out if unwanted
      # PERF="perf record -o \$(hostname).trace"
      BCAST="sbcast $RESTART /tmp/restart.13.silo"

      REGRID=$(printf "%.0f" $( bc <<< "scale=6;(1 + $LEVEL - $RESTART_LEVEL)" ))

      PROGRAM_ARGS="--config_file=v1309.ini --restart_file=/tmp/restart.13.silo --cuda_streams_per_locality=128 --cuda_streams_per_gpu=128 --p2p_kernel_type=SOA_CPU --p2m_kernel_type=SOA_CPU --multipole_kernel_type=SOA_CPU --max_level=${LEVEL} --extra_regrid=$REGRID"

      for THREADS_PERTASK in 12
      do
        PROGRAM_PARAMS="${MPI_ENABLE} ${FAB_ENABLE} --hpx:threads=${THREADS_PERTASK} ${HPX_ARGS} ${PROGRAM_ARGS}"
        write_script
      done
    done
  done
done
