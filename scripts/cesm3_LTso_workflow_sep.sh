#!/bin/bash

# ======================================================
# CMIP7 LTso TEMPLATE SCRIPT
# Modify indicated sections
# ====================================================== 

TOOLSROOT=/glade/work/nanr/cesm_tags/CASE_tools/CMIP7_workflow/

########################
##  Case details
########################
cesmtag=cesm3_0_beta09
project=CESM0024
compset=B1850C_MTso 
compset_longname=1850C_CAM70%MT_CLM60%BGC-CROP_CICE_MOM6%MARBL-BIO_MOSART_CISM2%GRIS-EVOLVE_WW3_SESP
resolution=ne30pg3_t233_wg37
useresoln=ne30_t233_wgx3

git_repo=git@github.com:NCAR/cesm_dev.git

CASENAME=b.e30_${cesmtag:(-8)}.${compset}.${useresoln}.workflowTest.008

echo "creating $CASENAME"

########################
## Set atm output frequency
########################
#do_hr3=true
#do_hr6=true
#do_dy=true

## copy ICs from Cecile's directory (TEMPORARY)
do_ics=false

########################
## Set ice output format (CMOR ready)
########################
do_cice_cmor=true

########################
## Set run instructions
########################
stop_n=2
stop_option=nyears
resubmit=10

if [ "${USER}" == "cmip7" ]; then
    ########################
    ## connected as cmip7 user
    ########################
     echo $'\n----- USER == CMIP7 -----\n'
     echo $'\n----- Setting CMIP7 user defaults -----\n'
     do_git_archive=true
     do_download_code=true
     do_create_newcase=true
     do_case_setup=true
     do_case_build=true
     do_case_submit=true
     do_tseries=true
     do_cmor=true
     do_cupid=true
     casedir=$WORK/cases/
     CODE_ROOT=$WORK/cesm_tags/
else
    ########################
    ## Set flags to do stuff ----
    ########################
    do_git_archive=false
    do_download_code=true
    do_create_newcase=true
    do_case_setup=true
    do_case_build=false
    do_case_submit=false
    do_tseries=false
    do_cupid=true
    do_cmor=false
    casedir=$SCRATCH/workflow_testcase/
    CODE_ROOT=$SCRATCH/cesm_tags/
fi
CASEROOT=$casedir/$CASENAME
RUNDIR=$SCRATCH/$CASENAME

########################
## Set Case Details
########################
REFCASE=b.e30_alpha08o.B1850C_MTso.ne30_t232_wgx3.338
REFDATE=0025-01-01

########################
## Clone the repository
########################
path=${CODE_ROOT}/${cesmtag}

if [[ $do_download_code != true || -d "${path}" ]]; then
     echo $'\n----- Skipping code download -----\n'
else
     mkdir -p ${CODE_ROOT}
     echo $'\n----- Downloading CESMROOT -----\n'

     cd ${CODE_ROOT}

     # clone the repo and get the cesm tag
     git clone https://github.com/ESCOMP/cesm $cesmtag -b $cesmtag
     cd $cesmtag

     # check out the components
     ./bin/git-fleximod update

     ### START ----- Remove when we are in production
     ###############################################
     ## Update the ccs_config to the workflow branch
     ###############################################
     #cd ccs_config
     #git checkout add_cmip7_workflow_amon_basic
     ### END ----- Remove when we are in production

fi

########################
## Create new case
########################
if [[ $do_create_newcase != true ]]; then
     echo $'\n----- Skipping create_newcase -----\n'
else
    path=${CASEROOT}
    if [ -d "${path}" ]; then
        echo "ERROR: CASE Directory already exists. Not overwriting"
        exit 20
    fi
    #${CODE_ROOT}/${cesmtag}/cime/scripts/create_newcase \
        #--case ${CASEROOT}  \
        #--compset ${compset_longname} \
	#$add_workflow        \
	#--res ${resolution} \
        #--run-unsupported  \
	#--project ${project} 
    ${CODE_ROOT}/${cesmtag}/cime/scripts/create_newcase \
        --case ${CASEROOT}  \
        --compset ${compset} \
	$add_workflow        \
	--res ${resolution} \
        --run-unsupported  \
	--project ${project} 
fi

########################
## copy script to CASEROOT directory
########################
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

echo $SCRIPT_PATH

mkdir -p "${CASEROOT}/provenance_script"
cp "$SCRIPT_PATH" "${CASEROOT}/provenance_script/$SCRIPT_NAME"


########################
## If necessary:  copy env_mach_pes.xml
########################
cp $TOOLSROOT/pe_layout/env_mach_pes.xml $CASEROOT


########################
## Set up 
########################
cd ${CASEROOT}
./case.setup

########################
## namelists
########################
 
### /glade/work/cmip7/cesm_tags/cesm3.0-alphabranch/cime_config/usermods_dirs
### /glade/work/cmip7/cesm_tags/cesm3.0-alphabranch/components/cam/cime_config/usermods_dirs/CMIP6_B1850

# ***** TO DO *****
# needs to have usermods_dirs CMIP6_B1850 
# ./create_newcase --user-mods-dir /glade/work/cmip7/cesm_tags/cesm3.0-alphabranch/components/cam/cime_config/usermods_dirs/CMIP6_B1850

# Edit each of the cmip7 workflow scripts to specify options to skip cmor or timeseries generation
# if both are false these files won't exist in the case directory
cmfiles=(".amon" ".lmon")
for f in "${cmfiles[@]}"; do
  if [[ -f "$f" ]]; then
      if [[ $do_cmor == false ]]; then
          echo "add skip-cmor option in $f"
          sed -i 's/--caseroot/--skip-cmor --caseroot/g' "$f"
      fi
      if [[ $do_tseries == false ]]; then
          echo "add skip-timeseries option in $f"
          sed -i 's/--caseroot/--skip-timeseries --caseroot/g' "$f"
      fi
  fi
done

date=`date "+%Y-%m-%d %H:%M:%S"`

if [ "${USER}" == "cmip7" ]; then
    echo "$date: Created in cmip7 account by $SUDO_USER" >> CaseStatus
else
    echo "$date: Created by $USER" >> CaseStatus
fi
echo " ---------------------------------------------------" >> CaseStatus

########################
## user_nl_cam
########################

cp user_nl_cam user_nl_cam-OTB

cat <<EOF> user_nl_cam
! Users should add all user specific namelist changes below in the form of 
! namelist_var = new_namelist_value 

!!      mon,   dy,  h6,  h3,  h1,  h6,  dy,  dy
!!       f1,   f2,  f3,  f4,  f5,  f6,  f7,  f8
!!       h0,   h1,  h2,  h3,  h4,  h5,  h6,  h7
nhtfrq =  0,  -24,  -6,  -3,  -1,  -6, -24, -24
mfilt  =  1,  365, 146, 292,  80,  73, 365,  73
ndens  =  2,    2,   2,   2,   2,   2,   1,   1
interpolate_output = .false., .false., .false., .false.

empty_htapes = .true.


EOF

## Add fincl1 (monthly)
cat $TOOLSROOT/user_nl_files/r1/user_nl_cam-fincl1-mon >> user_nl_cam


if [[ $do_dy == true ]]; then
echo "adding daily output"
cat $TOOLSROOT/user_nl_files/r1/user_nl_cam-fincl2-day >> user_nl_cam
fi

# 6 hourly
if [[ $do_hr6 == true ]]; then
echo "adding hour_6 output"
cat $TOOLSROOT/user_nl_files/r1/user_nl_cam-fincl3-hr6 >> user_nl_cam
fi

# 3 hourly
if [[ $do_hr3 == true ]]; then
echo "adding hour_3 output"
cat $TOOLSROOT/user_nl_files/r1/user_nl_cam-fincl4-hr3 >> user_nl_cam
fi

#Add the other stuff
cat <<EOF>> user_nl_cam

!phys_grid_ctem_nfreq=-6
!phys_grid_ctem_zm_nbas=120
!phys_grid_ctem_za_nlat=90

seasalt_emis_scale = 1.6
clubb_c8 = 4.6
cldfrc_dp1 =  0.1
dust_emis_fact = 3.2
micro_mg_vtrmi_factor = 1.2
zmconv_c0_lnd = 0.0035D0
micro_mg_dcs = 500.D-6
microp_aero_wsub_scale = 0.8

se_statefreq = 144

&prescribed_ozone_nl
 prescribed_ozone_cycle_yr              =    1850
 prescribed_ozone_datapath              = '/glade/derecho/scratch/tilmes/archive/b.e30_alpha07c_cesm.B1850C_MTt4s.ne30_t232_wgx3.251.001/atm/proc/ozone_strataero_day_5'
 prescribed_ozone_file          = 'ozone_strataero_b.e30_alpha07c_cesm.B1850C_MTt4s.ne30_t232_wgx3.251.001_1850climo_zm_5day_c251204.nc'
 prescribed_ozone_name          = 'O3'
 prescribed_ozone_type          = 'CYCLICAL'
/
&prescribed_strataero_nl
 prescribed_strataero_cycle_yr          =       1850
 prescribed_strataero_datapath          = '/glade/derecho/scratch/tilmes/archive/b.e30_alpha07c_cesm.B1850C_MTt4s.ne30_t232_wgx3.251.001/atm/proc/ozone_strataero_day_5'
 prescribed_strataero_file              = 'ozone_strataero_b.e30_alpha07c_cesm.B1850C_MTt4s.ne30_t232_wgx3.251.001_1850climo_zm_5day_c251204.nc'
 prescribed_strataero_type              = 'CYCLICAL'
 prescribed_strataero_use_chemtrop              =   .true.
/
 tracer_cnst_cycle_yr           =    1850
  tracer_cnst_datapath           = '/glade/derecho/scratch/tilmes/archive/b.e30_alpha07c_cesm.B1850C_MTt4s.ne30_t232_wgx3.251.001/atm/proc/TracerCnstCyclical1850'
  tracer_cnst_file               = 'tracer_cnst_MTt4s_halons_3Dmonthly_1850climo251_c20251209.nc'
  tracer_cnst_filelist           = ''
  tracer_cnst_specifier          = 'O3','OH','NO3','HO2','HALONS'
  tracer_cnst_type               = 'CYCLICAL'

stream_ndep_data_filename              = '/glade/derecho/scratch/tilmes/archive/b.e30_alpha07c_cesm.B1850C_MTt4s.ne30_t232_wgx3.251.001/atm/proc/DepositionCyclical1850/fndep_clm_B1850C_MT4s.1850monthly.ne30_c251220.nc'


EOF

########################
## user_nl_clm
########################

cp user_nl_clm user_nl_clm-OTB
cp $TOOLSROOT/user_nl_files/r1/user_nl_clm-ctsm5.3.0 ${CASEROOT}/user_nl_clm

########################
## user_nl_cpl
########################

cat <<EOF> user_nl_cpl
histaux_l2x1yrg = .true.
EOF

########################
## user_nl_cice
########################

# start with the 
if [[ $do_cice_cmip7 == true ]]; then
  cp /glade/work/dbailey/cesm3_0_alpha08o/components/cice/cime_config/usermods_dirs/cmip7/user_nl_cice ${CASEROOT}/
fi

########################
## user_nl_mom
########################

cat <<EOF> user_nl_mom
INPUTDIR = "/glade/derecho/scratch/gmarques/g.e30_a07g.GW1850MARBL_JRA.TL319_t232_wgx3_hycom1_N75.2025.152/run/INPUT"
MEKE_GEOMETRIC_ALPHA = 0.07
SMAGORINSKY_KH = False
MAXTRUNC = 1.0E6

! Leith+E Settings
TAPER_LEITHY = True
LEITH_BI_CONST = 85.0
LEITHY_CK = 1.0
LEITHY_DEPTH = 1000.0
LEITHY_WIDTH = 500.0

! Background KH
USE_KH_BG_2D = True
KH_BG_2D_FILENAME = "KH_BG_2D.nc"
KH_BG_2D_VARNAME = "KH"

! Resolution scaling:
!! GM & Redi the same
!! Don't apply scaling to Laplacian viscosity, which is the 2D background
RESOLN_SCALED_KH = False
RESOLN_SCALED_KHTH = True  ! Already using, here for clarity
RESOLN_SCALED_KHTR = True  ! Already using, here for clarity
KH_RES_SCALE_COEF = 0.5    ! Tighter around the equator
KH_RES_FN_POWER = 6        ! Already using, here for clarity
VISC_RES_SCALE_COEF = 0.5  ! Used for KHTR
VISC_RES_FN_POWER = 6      ! Used for KHTR
INTERPOLATE_RES_FN = True  ! Only computes resolution fn once, then interpolates
EOF


########################
## START TEMPORARY SECTION
## won't need by the time we are in production
###---------------------

cp /glade/derecho/scratch/hannay/archive/b.e30_alpha08o.B1850C_MTso.ne30_t232_wgx3.338/rest/0015-01-01-00000/* $SCRATCH/${CASENAME}/run/
cp -pR /glade/campaign/cesm/cesmdata/cseg/runs/cesm2_0/b.e30_alpha08o.B1850C_MTso.ne30_t232_wgx3.338/SourceMods/src.* $CASEROOT/SourceMods/

###---------------------
## END TEMP SECTION
#########################33

cd $CASEROOT
./preview_namelists

########################
## add to github repo
########################

if [[ $do_git_archive == true ]]; then
    cd ${CASEROOT}  
    cp $curdir
    ./xmlchange CASE_GIT_REPOSITORY=$git_repo

fi

########################
## timeseries
########################
if [[ $do_tseries == true ]]; then
   ## => the timeseries will be part of pf the workflow 
   echo "do_tseries == $do_tseries"
fi

########################
## CUPID
########################
if [[ $do_cupid == true ]]; then
   echo "do_cupid == $do_cupid"
   ./xmlchange RUN_POSTPROCESSING=TRUE
   ./xmlchange CUPID_CMORIZATION=TRUE
   ./xmlchange CUPID_NICKNAME=my_test_case
   ./xmlchange CUPID_STOP_N=9999
   #./xmlchange CUPID_BASELINE_ROOT=/glade/campaign/cesm/development/cross-wg/diagnostic_framework/CESM_output_for_testing
   ./xmlchange CUPID_BASELINE_ROOT=/glade/derecho/scratch/hannay/archive # If run was done by someone else or output was moved to campaign, set this accordingly
   ./xmlchange CUPID_BASELINE_CASE=b.e30_alpha09d_m.B1850C_MTso_Gris_Marbl.ne30_t233_wgx3.374
   ./xmlchange CUPID_BASE_NICKNAME=374
   ./xmlchange CUPID_BASE_STOP_N=116            # Number of years of output from the baseline case
   ./xmlchange CUPID_REGRID_BASE_ATM_FILE=NONE  # Only run this if CAM interpolating output to the FV grid already but output from the case you are running is on the ne30 grid
   ./xmlchange CUPID_REGRID=TRUE
   #./xmlchange CUPID_REGRID_ATM_FILE=NONE       # This turns off remapping for the current case, even if CUPID_REGRID=TRUE
fi


########################
## CMORization
########################
if [[ $do_cmor == true ]]; then
   ## => CMORization
   echo "do_cmor == $do_cmor"
fi

########################
## build and submit
########################

cd ${CASEROOT}
./xmlchange JOB_PRIORITY=premium
./xmlchange RESUBMIT=${resubmit},STOP_N=${stop_n},STOP_OPTION=${stop_option}
./xmlchange REST_OPTION=nyears,REST_N=1
./xmlchange RUN_REFCASE=${REFCASE},RUN_REFDATE=${REFDATE}

if [[ $do_ics == true ]]; then
cp /glade/derecho/scratch/hannay/archive/b.e30_alpha08o.B1850C_MTso.ne30_t232_wgx3.338/rest/$REFDATE-00000/* $RUNDIR/
./xmlchange GET_REFCASE=FALSE
fi

if [[ $do_case_build == true ]]; then
   qcmd -A ${project} -- ./case.build
fi
if [[ $do_case_submit == true ]]; then
   ./case.submit
fi

