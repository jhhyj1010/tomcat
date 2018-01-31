#!/bin/sh -x

echo "`whoami` Start installer build"
BUILD_VIEW=sybinstrs1571sp304_huiji_vu
RS_VIEW=rs1571sp305_installer_vu
RS_OFFICIAL_VIEW=rs1571sp305_build_vu
RS_BUILD_SUC_TIME=/usr/u/huiji/tmp/.rs_official_suc_time
RELEASE=305

 
# Avoid deny of access RS source view
if [ ! -d /view/${BUILD_VIEW} ]
then
    calm -v ${BUILD_VIEW} -c ct pwv
fi
if [ ! -d /view/${RS_OFFICIAL_VIEW} ]
then
    calm -v ${RS_OFFICIAL_VIEW} -c ct pwv
fi
if [ ! -d /view/${RS_VIEW} ]
then
    calm -v ${RS_VIEW} -c ct pwv
fi

. /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
echo "DROP location: ${DROP_LOCATION}"

#--- Generate new CYCLE LABEL for drop
YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
WEEK=`date +%W`
WEEKDAY=`date +%w`
LINUX_WEEK=`date +%W`
PRE_WEEK=`expr $WEEK - 1`
if [ $WEEK -lt 10 ]
then
    WEEK="0$WEEK"
fi

CYCLE_LABEL=${YEAR}CW${LINUX_WEEK}
date=`date +%Y%m%d`

INSTALLER_BUILD_FLAG=FALSE
#--- Get latest successful RMA version number
rma_version=`ls -lrt /remote/repeng7/installer/staging/rs/1571/rma/sp305 | tail -n 1|awk '{print $9}'`
RMA_SUC_FILE=/remote/repeng7/installer/staging/rs/1571/rma/sp305/${rma_version}/build.suc

#--- Check if Last RS official build success or not
if [ -e ${RS_BUILD_SUC_TIME} ]
then
    rm -rf ${RS_BUILD_SUC_TIME}
fi

#--- Check RS/RMA to see if installer build is needed ---#
## check RMA
RMA_UPDATE=FALSE
if [ -e ${RMA_SUC_FILE} ]
then
    if [ "${rma_version}" = "${RMA_VERSION}" ]
    then
        echo "No need to update RMA!"
    else
        RMA_UPDATE=TRUE
    fi
fi

## check RS
RS_UPDATE=FALSE
REPSRVR_UPDATE=FALSE
RSINIT_UPDATE=FALSE
SUBCMP_UPDATE=FALSE

RS_UPDATE_WINX=FALSE
REPSRVR_UPDATE_WINX=FALSE
RSINIT_UPDATE_WINX=FALSE
SUBCMP_UPDATE_WINX=FALSE

diff /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/bin/repserver /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/bin/repserver
if [ $? -ne 0 ]
then
    echo "repserver is updated!"
    REPSRVR_UPDATE=TRUE
fi
diff /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/install/rs_init /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/install/rs_init
if [ $? -ne 0 ]
then
    echo "rs_init is updated!"
    RSINIT_UPDATE=TRUE
fi
diff /view/${RS_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/bin/rs_subcmp /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/sybase/linuxamd64/rep/bin/rs_subcmp
if [ $? -ne 0 ]
then
    echo "rs_subcmp is updated!"
    SUBCMP_UPDATE=TRUE
fi
if [ "${REPSRVR_UPDATE}" = "TRUE" ] || [ "${RSINIT_UPDATE}" = "TRUE" ] || [ "${SUBCMP_UPDATE}" = "TRUE" ]
then
    RS_UPDATE=TRUE
fi
#-----------------For Winx
diff /view/${RS_VIEW}/calm/repl/svr/sybase/winx64/rep/bin/repsrvr.exe /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/sybase/winx64/rep/bin/repsrvr.exe
if [ $? -ne 0 ]
then
    echo "WINX repserver is updated!"
    REPSRVR_UPDATE_WINX=TRUE
fi
diff /view/${RS_VIEW}/calm/repl/svr/sybase/winx64/rep/install/rs_init.exe /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/sybase/winx64/rep/install/rs_init.exe
if [ $? -ne 0 ]
then
    echo "WINX rs_init is updated!"
    RSINIT_UPDATE_WINX=TRUE
fi
diff /view/${RS_VIEW}/calm/repl/svr/sybase/winx64/rep/bin/subcmp.exe /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/sybase/winx64/rep/bin/subcmp.exe
if [ $? -ne 0 ]
then
    echo "WINX rs_subcmp is updated!"
    SUBCMP_UPDATE_WINX=TRUE
fi
if [ "${REPSRVR_UPDATE_WINX}" = "TRUE" ] || [ "${RSINIT_UPDATE_WINX}" = "TRUE" ] || [ "${SUBCMP_UPDATE_WINX}" = "TRUE" ]
then
    RS_UPDATE_WINX=TRUE
fi


if [ "${RMA_UPDATE}" = "TRUE" ] || [ "${RS_UPDATE}" = "TRUE" ] || [ "${RS_UPDATE_WINX}" = "TRUE" ]
then
    INSTALLER_BUILD_FLAG=TRUE
fi

if [ "${INSTALLER_BUILD_FLAG}" = "FALSE" ]
then
    echo "No need to update SRS installer..."
    exit 1
fi

#--------------------------------------------------------#

RS_SUC_NUM=`ls -lrt /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/code/*/logs/*.suc| grep linuxamd64 | wc -l`
if [ ${RS_SUC_NUM} -lt 2 ]
then
    echo "Jesson: Latest RS official build failed!"
    exit 1
else
    echo "Jesson: Latest RS official build success!"
    cat /view/${RS_OFFICIAL_VIEW}/calm/repl/svr/code/*/logs/*.suc |sort |tail -n 1 > ${RS_BUILD_SUC_TIME}
    Month=`cat ${RS_BUILD_SUC_TIME} | awk '{print $2}'`
    Day=`cat ${RS_BUILD_SUC_TIME} | awk '{print $3}'`
    Year=`cat ${RS_BUILD_SUC_TIME} | awk '{print $6}'`
    Hour=`cat ${RS_BUILD_SUC_TIME} | awk '{print $4}' | tr ':' ' ' | awk '{print $1}'`
    Min=`cat ${RS_BUILD_SUC_TIME} | awk '{print $4}' | tr ':' ' ' | awk '{print $2}'`
    Sec=`cat ${RS_BUILD_SUC_TIME} | awk '{print $4}' | tr ':' ' ' | awk '{print $3}'`
    
    echo "Jesson: Latest timestamp for RS is ${Day}-${Month}-${Year}.${Hour}:${Min}:${Sec}"
    NewHour=`expr $Hour + 5`
    if [ ${NewHour} -ge 24 ]
    then
        NewHour=`expr $NewHour - 24`
        Day=`expr $Day + 1`
    fi
    TIME_STAMP="${Day}-${Month}-${Year}.${NewHour}:${Min}:${Sec}"
    echo "Jesson: Timestamp used for freeze RS view is ${TIME_STAMP}"
    #calm -v ${RS_VIEW} -c /usr/u/lrabld/bin/ct-freeze 8-Feb-2016.18:00:00
    calm -v ${RS_VIEW} -c /usr/u/lrabld/bin/ct-freeze ${TIME_STAMP} # 27-jan-2016.15:00:00 #${TIME_STAMP}
fi

#------------------------------#
# to avoid format issues#
dos2unix /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
CYCLE_LABEL=${YEAR}CW${WEEK}_${WEEKDAY}
DROP_DIR=/remote/repqa25/installer/drops/1571/sp${RELEASE}
sed -i "s/^\s*CYCLE_LABEL=.*/CYCLE_LABEL=$CYCLE_LABEL/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
sed -i "s/^\s*REP_SOURCE_VIEW=.*/REP_SOURCE_VIEW=${RS_VIEW}/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
sed -i "s/^\s*DROP_LOCATION=.*/DROP_LOCATION=\/remote\/repqa25\/installer\/drops\/1571\/sp${RELEASE}/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
if [ -e ${RMA_SUC_FILE} ]
then
    sed -i "s/^\s*RMA_VERSION=.*/RMA_VERSION=${rma_version}/g" /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
fi

#calm -v ${BUILD_VIEW} -c /calm/dub/sybinst/tools/buildall.sh || exit $?
/usr/atria/bin/cleartool setview ${BUILD_VIEW} <<EOF
cd /calm/dub/sybinst/tools
./buildlinux.sh || exit $?
EOF

if [ "${RS_UPDATE_WINX}" = "TRUE" ]
then
/usr/atria/bin/cleartool setview ${BUILD_VIEW} <<EOF
cd /calm/dub/sybinst/tools
./buildwinx.sh || exit $?
EOF
fi

. /view/${BUILD_VIEW}/calm/dub/sybinst/tools/profile
#--- Remove Previous Week Drops ---#
rm -rf ${DROP_LOCATION}/${YEAR}CW${PRE_WEEK}_*
#----------------------------------#

#--- Remove Previous Installed Files ---#
rm -rf /replinuxb10-1/users/lrabld/RS-TEST/rs1571.sp305.linuxamd64.*/*
#---------------------------------------#


#-------------------------#

exit 0