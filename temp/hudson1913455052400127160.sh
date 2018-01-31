#!/bin/sh 

echo "user is `whoami`"

rma_view=sybinstrsng1571sp303_installertriggerbyrmaSP304_vu

if [ ! -e /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.txt ]
then
    touch /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.txt
fi

if [ ! -e /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.log ]
then
    touch /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.log
fi

export rma_view

chmod 777 /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.txt

/usr/u/huiji/installer/publish/backup/showRMAver sp304 | grep "Build-Number" | head -n 1 | awk -F ': ' '{print $2}' > /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.txt

new_rma_no=`/usr/u/huiji/installer/publish/backup/showRMAver sp304 | grep "Build-Number" | head -n 1 | awk -F ': ' '{print $2}'`

echo "Jesson: the latest rma number for sp305 is $new_rma_no"

/usr/atria/bin/cleartool setview ${rma_view} <<EOF

cd /calm/dub/sybinst/tools
stage_rma-jesson-sp305

buildall.sh | tee /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.log


EOF
sendErrorMail()
{
	tmpmailfile=/tmp/tmp_rma_mail_file_$$.txt
	echo "From: rma_build@sap.com" >> $tmpmailfile
	echo "To: jesson.ji@sap,lisa.lew@sap.com" >> $tmpmailfile
	echo "Subject: RMA staging/build for sp304 failed!" >> $tmpmailfile
	/usr/sbin/sendmail -t < $tmpmailfile
	rm -rf $tmpmailfile
}

sendSuccessMail()
{
	tmpmailfile_succ=/tmp/tmp_rma_succ_mail_file_$$.txt
	echo "From: rma_build@sap.com" >> $tmpmailfile_succ
	echo "To: jesson.ji@sap,lisa.lew@sap.com" >> $tmpmailfile_succ
	echo "Subject: RMA staging/build for sp304 successful! RMA version ${new_rma_no} is now available for SRS installer" >> $tmpmailfile_succ
	/usr/sbin/sendmail -t < $tmpmailfile_succ
	rm -rf $tmpmailfile_succ
}

grep cannot /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.log > /dev/null
if [ $? -eq 0 ]
then
    echo "RMA build failed!"
    sendErrorMail
    exit 1
fi

grep -i error /remote/repeng10/rs_nightly/.sp304_rma_trigger_by_b3.log > /dev/null
if [ $? -eq 0 ]
then
    echo "RMA build failed with ERROR!"
    sendErrorMail
    exit 1
fi
sendSuccessMail
exit 0