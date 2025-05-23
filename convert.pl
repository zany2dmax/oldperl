#!/usr/bin/perl 
# Jeff Leggett for SDX to Sterling Migration
# July 2007
# NOTE: Rough functionality is complete, some fleshing out
#       will be needed for the MBX configuration
#
# Josh Forester
# Updates:
# Added printout of virtual root sections.
# Moved USERXGROUP tags to inside loop so they are printed for each group
#    the user is in.
#
# Areas to look at in future:
# 1.  inner MBXVIRTUAL may represent single virtual root, and so all instances
#     should be wrapped by outer rather than having multiple inner-outers
# 2.  SHA hash may need slight modification for XML export
# 3.  POLICY_ID will need to be changed to a policy created for access control
# 4.  all values in USER need to be verified in case literals are needed
# 5.  email isn't parsed from LDIF
# 6.  printout of XML for mailbox and associated permission.  
#     xml for permission and associated group.
#     (see FullNewTransmissionImp1.0.xml)
#
use strict;
use warnings;

use XML::Writer;

#my ($NAME, $UID, $PWD, $GN, $SN);
#my ($CN,$TMP,$TMP1,$GRPNAME);
#our $UC = 0; our $GC = 0; 
#my (@CN, @SN, @UID, @PWD, @GN, @GRPNAME);
our @USERS;
our @GROUPS;

sub ParseLDIF {
  my ($NAME, $UID, $PWD, $GN, $SN);
  my ($CN,$TMP,$TMP1,$GRPNAME);
  our $UC = 0; 
  our $GC = 0; 
  our (@CN, @SN, @UID, @PWD, @GN, @GRPNAME);
  my $ldiffile = $ARGV[0];
  die "usage: $0 ldiffile\n" unless $ldiffile;
  open (LDIFFILE, $ldiffile) || die "$ldiffile: $!";

  my $userevent = 0;
  my $grpevent = 0;
  while (<LDIFFILE>) {
	chomp;
	#print "PREPARSE LINE: $_";
	if (/^dn: uid/) { $userevent = 1; next; }
	if ($userevent) {  
	  if ($_ =~ /^uid/) { 
		 ($NAME,$UID) = split /: /, $_, 2; 
		 $UID[$UC] = $UID; next; 
	  }
	  if ($_ =~ /^user/) { 
	     ($NAME, $PWD) = split /: /, $_, 2; 
		 $PWD[$UC] = $PWD; next;
	  }
	  if ($_ =~ /^give/) { 
		 ($NAME, $GN) = split /: /,$_, 2; 
		 $GN[$UC] = $GN; next; 
	  }
	  if ($_ =~ /^sn/) { 
		 ($NAME,$SN) = split /: /, $_, 2; 
		 $SN[$UC] = $SN;  next;
	  }
	  if ($_ =~ /^$/) { $userevent = 0; $UC++; next; }
	}
	if (/^dn: cn/) { $grpevent = 1; next; }
	if ($grpevent) {
      if ($_ =~ /^cn/) {
		 ($NAME, $CN) = split /: /, $_, 2;
		 $CN[$GC] = $CN; next; 
	  }
	  if ($_ =~ /^uniquemember/) {
#	print "PRESPLIT LINE: $_ \n";
	     ($NAME, $TMP1) = split /: /, $_;
#	print "NAME: $NAME, PRE_SPLIT: $TMP1\n";
		 ($TMP,$GRPNAME) = split /=/, $TMP1;	  	
#	print "NAME: $TMP, PRE_SPLIT: $GRPNAME\n";
		 if ($GRPNAME eq "") { $GRPNAME = ""; }
		 $GRPNAME[$GC] = $GRPNAME[$GC] . ":" . $GRPNAME; next;
	  }
	}
	if ($_ =~ /^$/) { $grpevent = 0; $GC++; next; }
  }
  close (LDIFFILE);

  #print "USERS:\n";
  for (my $I=0; $I<scalar(@UID); $I++) {
  	$USERS[$I] =  "$UID[$I]:$PWD[$I]:$GN[$I]:$SN[$I]";
#	print "$USERS[$I]\n";
  }
  #print "GROUPS:\n";
  for (my $I=0; $I<$GC; $I++) {
    $GROUPS[$I] =  "$CN[$I]$GRPNAME[$I]";
#	print "$GROUPS[$I]\n";
  }
}

our $writer = new XML::Writer(DATA_MODE => 1);

sub StartXML {
   $writer->xmlDecl("UTF-8");
   $writer->startTag('SI_RESOURCES','xmlns' => 'http://www.stercomm.com/SI/SI_IE_Resources', 'xmlns:xsi'=>'http://www.w3.org/2001/XMLSchema-instance','GISVersion'=>'4.1.0-1969');
}

sub EndXML {
	$writer->endTag('SI_RESOURCES');
    $writer->end();
}

sub OutputUsersGroupsXML {
  my ($UID, $PWD, $GN, $SN);
  $writer->startTag('USERS');
  $writer->startTag('USER');
  for (my $I=0; $I<scalar(@USERS); $I++) { # Need = ?
	($UID,$PWD,$GN,$SN) = split /:/, $USERS[$I];
    $writer->startTag('METADATA');
    $writer->dataElement('USER_ID' => $UID);
	$writer->dataElement('PASSWORD' => $PWD);
    $writer->dataElement('LANG' => '');
    $writer->dataElement('EMAIL' => '');
    $writer->dataElement('FNAME' => $GN);
    $writer->dataElement('LNAME' => $SN);	
    $writer->dataElement('PAGER' => '');
    $writer->dataElement('VERSION' => '');
    $writer->dataElement('DOWNLOAD_TIME' => '');
    $writer->dataElement('SUPER' => ''	);	
    $writer->dataElement('PARENT_ID' => '');
    $writer->dataElement('ENTITY_ID' => ''); 
    $writer->dataElement('STATUS' => '1');
    $writer->dataElement('TIMEOUT' => '' );	
    $writer->dataElement('POLICY_ID' => 'ACPolicy');
    $writer->dataElement('PWD_MOD_DATE' => '' );
    $writer->dataElement('DASH_USER_ID' => '');
    $writer->dataElement('CONFIRM_VALUE' => '');
    $writer->dataElement('MODIFIED' => '');
    $writer->dataElement('CREATED' => '');
	$writer->dataElement('LAST_LOGIN' => '');
    $writer->dataElement('DISABLED' => ''); 
	$writer->dataElement('SECURITY_CODE' => '');
    $writer->dataElement('CHANGE_PASS_NEXT' => '');
    $writer->endTag('METADATA');
    $writer->startTag('USERDEPENDENTS');
    $writer->startTag('USERXGROUPS');
    for (my $J=0; $J<scalar(@GROUPS); $J++) {
	   my $GRPNAME = $GROUPS[$J];
       if ( $GRPNAME =~ /$UID/ ) {
		   ($GRPNAME,my $USERSINGROUP) = split /:/, $GRPNAME,2;
    		   $writer->startTag('USERXGROUP');
           $writer->startTag('METADATA');
		   $writer->dataElement('GROUP_ID' => $GRPNAME);
		   $writer->dataElement('USER_SUB_GROUP_ID' => $UID);
		   $writer->dataElement('REC_TYPE' => '');
		   $writer->dataElement('STATUS' => '1');
           $writer->endTag('METADATA');
    		   $writer->endTag('USERXGROUP');
	   } 
    }
    $writer->endTag('USERXGROUPS');
    $writer->endTag('USERDEPENDENTS');
  }
  $writer->endTag('USER');
  $writer->endTag('USERS');

  # write out virtual root info
  for (my $I=0; $I<scalar(@USERS); $I++) { # Need = ?
	($UID,$PWD,$GN,$SN) = split /:/, $USERS[$I];
    $writer->startTag('MBXVIRTUAL');
    $writer->startTag('MBXVIRTUAL');
    $writer->startTag('MBXVIRTUALROOT');
    $writer->dataElement('USER_ID' => $UID);
    $writer->dataElement('ROOT_MAILBOX_PATH' => '/dev_sdx');
    $writer->endTag('MBXVIRTUALROOT');
    $writer->startTag('MAILBOX');
    $writer->dataElement('BASEPATH' => '/dev_sdx');
    $writer->endTag('MAILBOX');
    $writer->endTag('MBXVIRTUAL');
    $writer->endTag('MBXVIRTUAL');
  }
}

# Hehe, the actual MAIN section - modules written for re-use in expanding 
# it later
ParseLDIF();
StartXML();
OutputUsersGroupsXML();
#OutpoutMBXXML();
EndXML();

 


