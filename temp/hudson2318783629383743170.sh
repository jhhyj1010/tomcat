#!/bin/sh -x

echo "`whoami` Start installer build"
BUILD_VIEW=sybinstrs1571sp306_huiji_vu
RS_VIEW=rs1571sp307_nightlybuild_vu
RELEASE=307
ASE_VIEW=ase160sp02plx_ase_vu

#--- ONLY one build process is allowed at the same time ---#
ps -ef | grep buildSybInstaller|grep perl
if [ $? -eq 0 ]
then
    MailFile=/tmp/build_precheck_$$.txt
    echo "From: srs_build@sap.com" >> $MailFile
    echo "To: celia.cui@sap.com" >> $MailFile
    echo "Cc: jesson.ji@sap.com,ge.yang01@sap.com" >> $MailFile
    echo "Subject: ONLY one installer build process allowed at the same time" >> $MailFile
    echo "There was already one SRS installer build process on rsng2.sjc.sap.corp, please start SP305_SRS_DAILY_BUILD_INTEGRATION after previous job complete!" >> $MailFile
    echo "Job Link: ${JOB_URL}" >> $MailFile
    echo "How to check whether installer build was on-going?" >> $MailFile
    echo "ps -ef | grep buildSybInstaller|grep perl" >> $MailFile
    /usr/sbin/sendmail -t < $MailFile
    rm -rf $MailFile
    #exit 1
fi
#----------------------------------------------------------#
 
# Avoid deny of access RS source view
if [ ! -d /view/${BUILD_VIEW} ]
then
    calm -v ${BUILD_VIEW} -c ct pwv
fi

if [ ! -d /view/${RS_VIEW} ]
then
    calm -v ${RS_VIEW} -c ct pwv
fi

if [ ! -d /view/${ASE_VIEW} ]
then
    calm -v ${ASE_VIEW} -c ct pwv
fi

. /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
echo "DROP location: ${DROP_LOCATION}"

#--- Generate new CYCLE LABEL for drop
YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
WEEK=`date +%W`
WEEKDAY=`date +%w`
PRE_WEEK=`expr $WEEK - 1`
if [ $WEEKDAY -eq 0 ]
then
    WEEKDAY=7
fi
date=`date +%Y%m%d`

#--- Get latest successful RMA version number
rma_version=`ls -lrt /remote/repeng7/installer/staging/rs/1571/rma/sp306 | tail -n 1|awk '{print $9}'`
RMA_SUC_FILE=/remote/repeng7/installer/staging/rs/1571/rma/sp306/${rma_version}/build.suc


#------------------------------#
# to avoid format issues#
dos2unix /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
CYCLE_LABEL=${YEAR}CW${WEEK}_${WEEKDAY}
DROP_DIR=/remote/repqa24/installer/drops/rs/1571/sp${RELEASE}
sed -i "s/^\s*CYCLE_LABEL=.*/CYCLE_LABEL=$CYCLE_LABEL/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
CYCLE_LABEL=${YEAR}CW${WEEK}_${WEEKDAY}
sed -i "s/^\s*REP_SOURCE_VIEW=.*/REP_SOURCE_VIEW=${RS_VIEW}/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
CYCLE_LABEL=${YEAR}CW${WEEK}_${WEEKDAY}
sed -i "s/^\s*DROP_LOCATION=.*/DROP_LOCATION=\/remote\/pbi_archive17\/daily_image\/SRS\/installer\/drops\/rs\/1571\/sp307/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
CYCLE_LABEL=${YEAR}CW${WEEK}_${WEEKDAY}
if [ -e ${RMA_SUC_FILE} ]
then
    sed -i "s/^\s*RMA_VERSION=.*/RMA_VERSION=${rma_version}/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
CYCLE_LABEL=${YEAR}CW${WEEK}_${WEEKDAY}
fi

calm -v ${BUILD_VIEW} -c /calm/dub/sybinst/tools/buildlinux.sh || exit $?
#/usr/atria/bin/cleartool setview ${BUILD_VIEW} <<EOF
#cd /calm/dub/sybinst/tools
#./buildlinux.sh || exit $?
#EOF


. /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile.ase
#--- Remove Previous Week Drops ---#
rm -rf ${DROP_LOCATION}/${YEAR}CW${PRE_WEEK}_*
#----------------------------------#

#--- Make latest link ----#
/usr/atria/bin/cleartool setview ${BUILD_VIEW} <<EOF
cd /calm/dub/sybinst/tools
sh -x create_icd_drop_jesson.sh
EOF
#calm -v ${BUILD_VIEW} -c 
#-------------------------#

#--- Stage CI library to ASE ---#
cd /remote/pbi_archive17/daily_image/SRS/installer/drops/rs/1571/sp307/ci_stage/
if [ -d /remote/pbi_archive17/daily_image/SRS/installer/drops/rs/1571/sp307/ci_stage/v-1.7.1_307_${CYCLE_LABEL} ]
then
    rm -rf /remote/pbi_archive17/daily_image/SRS/installer/drops/rs/1571/sp307/ci_stage/v-1.7.1_307_${CYCLE_LABEL}
fi
calm -v ${RS_VIEW} -c /remote/pbi_archive17/daily_image/SRS/installer/drops/rs/1571/sp307/ci_stage/createDrop.sh v-1.7.1_307_${CYCLE_LABEL} linuxamd64
cd -
#-------------------------------#

#--- Make CI link in SRS Drop ---#
cd ${DROP_LOCATION}/${CYCLE_LABEL}.drop
ln -s /remote/pbi_archive17/daily_image/SRS/installer/drops/rs/1571/sp307/ci_stage/v-1.7.1_307_${CYCLE_LABEL} CI
cd -
rm -rf ${DROP_LOCATION}/${CYCLE_LABEL}.drop/*.tgz  #remove unused tar files to save space
#--------------------------------#

#--- Make platform soft link under Drop area ---#
#cd ${DROP_LOCATION}/${CYCLE_LABEL}.drop
#ln -s ./untar/rs1571.sp305.linuxamd64.${CYCLE_LABEL} linuxamd64
#cd -
#-----------------------------------------------#

#--- Send out mail notification if pass ---#
RS_VERSION=`strings /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/bin/repserver |grep EBF | grep Replication`
CI_VERSION=`strings /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/lib64/libsybci.so |grep EBF | grep CI-`
OCS_VERSION=`strings /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/conn/lib/libsybsrv_r64.so |grep EBF | grep "SAP Server"`
CSI_VERSION=`strings /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/csi/shared64bit/libsybcsi_core210.so | grep CSI-`
RMA_VER=${RMA_VERSION}
## Generate SRS drop notification information
MAIL_FILE=/remote/repqa24/huiji/mail_file_$$
echo "From: srs_daily@sap.com" >> $MAIL_FILE
echo "To: jesson.ji@sap.com,celia.cui@sap.com,ge.yang01@sap.com" >> $MAIL_FILE
#echo "Cc: terry.ning@sap.com,DL P&I HANA Platform SYB-rsshastaff <DL_SYB-RSSHASTAFF@exchange.sap.corp>,DL P&I HANA Platform Rep QA_cn <DL_SYB-REPQA_CN@exchange.sap.corp>" >> $MAIL_FILE
echo "Subject: SRS SP307 Daily Installer Builid for Linuxamd64 Completed!" >> $MAIL_FILE
echo "CI Version: ${CI_VERSION}" >> $MAIL_FILE
echo "" >> $MAIL_FILE
echo "Repserver Version: ${RS_VERSION}" >> $MAIL_FILE
echo "" >> $MAIL_FILE
echo "OCS Version: ${OCS_VERSION}" >> $MAIL_FILE
echo "" >> $MAIL_FILE
echo "CSI Version: ${CSI_VERSION}" >> $MAIL_FILE
echo "" >> $MAIL_FILE
echo "RMA Build ID: ${RMA_VER}" >> $MAIL_FILE 
echo "" >> $MAIL_FILE
echo "Drop Location: ${DROP_LOCATION}/${CYCLE_LABEL}.drop" >> $MAIL_FILE
echo "" >> $MAIL_FILE
echo "" >> $MAIL_FILE
echo "ATTENTION: Daily drops are only kept for 1 week!!" >> $MAIL_FILE

/usr/sbin/sendmail -t < $MAIL_FILE
rm -rf $MAIL_FILE
#------------------------------------------#

echo "*************************************"
echo "Drop Location: ${DROP_LOCATION}"
echo "*************************************"

exit 0