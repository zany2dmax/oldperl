#!/etrade/bin/ksh
#
# Run the daily ACH & Wire scripts sequentially
#

# MAIN

bindir=$(dirname $0)

# Define common date and time functions.
. $bindir/et_datetime

# Define common authen utility functions.
. $bindir/et_authenutil

# Get yesterday's date and construct the working directory.
outdir=$ET_INSTANCE_ROOT/logs/cyota
date=$(ConvertDate number $(GetToday) -1)
dir=$outdir/$(DateToDir $date)

# Set up file paths.
achfile=$dir/addpayeeach.txt
rawwirefile=$dir/wire_instr.txt
wirefile=$dir/processedwires.txt
outfile=$dir/addpayee_events.txt

# Check the input/output directory.
if [[ ! -d $outdir ]]; then
  echo "$outdir does not exist"
  exit
fi
if [[ ! -w $outdir ]]; then
  echo "$outdir is not writable"
  exit
fi

# Create the output directory.
mkdir -p $dir

# Get the ACH data.
$bindir/addPayeeACH.pl

# Check that ACH data was generated.
if [[ ! -e $achfile ]]; then
  echo "$achfile does not exist.  addPayeeACH.pl had problems"
  exit
fi

# get the Wire data, this takes awhile
$bindir/get_wire_instr_cyota.pl -wire_type ID

# if the Wire data is not present, we had issues
if [[ ! -e $rawwirefile ]]; then
  echo "$rawwirefile does not exist.  get_wire_instr_cyota.pl had problems"
  exit
fi

# Remove duplicates in the Wire data.
mv $rawwirefile $rawwirefile.tmp
sort -u $rawwirefile.tmp > $rawwirefile
rm -f $rawwirefile.tmp

# All's good so far, process the Wire data
$bindir/processWireData.pl                   

if [[ ! -e $wirefile ]]; then
  echo "$wirefile does not exist.  processWireData.pl had problems"
  exit
fi

# get how many ACH and Wire records we had
ROWCOUNT=$(($(cat $achfile $wirefile | wc -l)+0))

echo "#FI Code: etrp" > $outfile
echo "#Date: $date"  >> $outfile
echo "#FI ID: etrp"  >> $outfile
echo "#Delimiter: |" >> $outfile
echo "#ADD_PAYEE|activity_time|event_type|user_id|other_account_id|other_account_routing_code|date_account_opened|user_agent|other_account_ownership|other_account_bank|other_account_name|other_account_nickname|other_account_reference_code|other_account_country|medium_used|" >> $outfile

# Add the User ID to the ALIAS DB if needed
tmpfile=/etrade/tmp/update_ACH_$$.tmp
cat $achfile $wirefile |
  awk -F\| '{print $3}' > $tmpfile
$bindir/get_uidmap.ksh -l -v $tmpfile
rm -f $tmpfile

cat $achfile $wirefile | $bindir/processUIDAddPayee.pl >> $outfile

echo "#Record Count: $ROWCOUNT" >> $outfile

#rm -f $achfile $rawwirefile $wirefile
