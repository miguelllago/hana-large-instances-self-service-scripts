#!/usr/bin/perl -w
#
# Copyright (C) 2017 Microsoft, Inc. All rights reserved.
# Specifications subject to change without notice.
#
# Name: removeTestStorageSnapshot.pl
#Version: 3.3
#Date 05/15/2018

use strict;
use warnings;
use Time::Piece;
use Date::Parse;
use Term::ANSIColor;
#Usage:  This script is used to remove the test snapshot that was performed while testing the connection to SAP HANA.
#
my $numSID = 9;
my $detailsStart = 11;
# Error return codes -- 0 is success, non-zero is a failure of some type
my $ERR_NONE=0;
my $ERR_WARN=1;

# Log levels -- LOG_INFO, LOG_WARN.  Bitmap values
my $LOG_INFO=1;
my $LOG_WARN=2;

# Global parameters
my $exitWarn = 0;
my $exitCode;

#
# Global Tunables
#
#DO NOT MODIFY THESE VARIABLES!!!!
my $version = "3.3";  #current version number of script
my @arrOutputLines;                   #Keeps track of all messages (Info, Critical, and Warnings) for output to log file
my @fileLines;                        #Input stream from HANABackupCustomerDetails.txt
my @strSnapSplit;
my @arrCustomerDetails;               #array that keeps track of all inputs on the HANABackupCustomerDetails.txt
my $strPrimaryHANAServerName;         #Customer provided IP Address or Qualified Name of Primay HANA Server.
my $strPrimaryHANAServerIPAddress;    #Customer provided IP address of Primary HANA Server
my $strSecondaryHANAServerName;       #Customer provided IP Address or Qualified Name of Seconary HANA Server.
my $strSecondaryHANAServerIPAddress;  #Customer provided IP address of Secondary HANA Server
my $filename = "HANABackupCustomerDetails.txt";
my $strSnapshotPrefix = "testStorage";                #The customer entered snapshot prefix that precedes the date in the naming convention for the snapshot
my $strUser;                          #Microsoft Operations provided storage user name for backup access
my $strSVM;                           #IP address of storage client for backup
my $strHANAAdmin;                     #Hdbuserstore key customer sets for paswordless access to hdbsql
my $sshCmd = '/usr/bin/ssh';          #typical location of ssh on SID
my $strHANASID = $ARGV[0];                     #The customer entered HANA SID for each iteration of SID entered with HANABackupCustomerDetails.txt

my $outputFilename = "";              #Generated filename for scipt output
my @snapshotLocations;                #arroy of all snapshots for certain volumes that match customer SID.
my @volLocations;                     #array of all volumes that match SID input by customer

my $filename = "HANABackupCustomerDetails.txt";
my $sshCmd = '/usr/bin/ssh';

my $verbose = 1;
my $HSR = 0;                          #used within only scripts, otherwise flagged to zero. **not used in this script**


#
# Name: runOpenParametersFiles
# Func: open the customer-based text file to gather required details
#

sub runOpenParametersFiles {
  open(my $fh, '<:encoding(UTF-8)', $filename)
    or die "Could not open file '$filename' $!";

  chomp (@fileLines=<$fh>);
  close $fh;
}

#
# Name: runVerifyParametersFile
# Func: verifies HANABackupCustomerDetails.txt input file adheres to expected format
#

sub runVerifyParametersFile {

  my $k = $detailsStart;
  my $lineNum;
  $lineNum = $k-3;
  my $strServerName = "HANA Server Name:";
  if ($fileLines[$lineNum-1]) {
    if (index($fileLines[$lineNum-1],$strServerName) eq -1) {
      logMsg($LOG_WARN, "Expected ".$strServerName);
      logMsg($LOG_WARN, "Verify line ".$lineNum." is for the HANA Server Name. Exiting");
      runExit($exitWarn);
    }
  }


  $lineNum = $k-2;
  my $strHANAIPAddress = "HANA Server IP Address:";
  if ($fileLines[$lineNum-1]) {
    if (index($fileLines[$lineNum-1],$strHANAIPAddress) eq -1  ) {
      logMsg($LOG_WARN, "Expected ".$strHANAIPAddress);
      logMsg($LOG_WARN, "Verify line ".$lineNum." is the HANA Server IP Address. Exiting");
      runExit($exitWarn);
    }
  }


  for my $i (0 ... $numSID) {

        my $j = $i*9;
        $lineNum = $k+$j;
        my $string1 = "######***SID #".($i+1)." Information***#####";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string1) eq -1) {
            logMsg($LOG_WARN, "Expected ".$string1);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string2 = "SID".($i+1);
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string2) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string2);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is for SID #$i. Exiting");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string3 = "###Provided by Microsoft Operations###";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string3) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string3);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string4 = "SID".($i+1)." Storage Backup Name:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string4) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string4);
            logMsg($LOG_WARN, "Verify line ".$lineNum." contains the storage backup as provied by Microsoft Operations. Exiting.");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string5 = "SID".($i+1)." Storage IP Address:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string5) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string5);
            logMsg($LOG_WARN, "Verify line ".$lineNum." contains the Storage IP Address. Exiting.");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string6 = "######     Customer Provided    ######";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string6) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string6);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string7 = "SID".($i+1)." HANA instance number:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string7) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string7);
            logMsg($LOG_WARN, "Verify line ".$lineNum." contains the HANA instance number. Exiting.");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string8 = "SID".($i+1)." HANA HDBuserstore Name:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string8) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string8);
            logMsg($LOG_WARN, "Verify line ".$lineNum." contains the HDBuserstore Name. Exiting.");
            runExit($exitWarn);
          }
        }
        $j++;
        $lineNum = $k+$j;
        if ($#fileLines >= $lineNum-1 and $fileLines[$lineNum-1]) {
          if ($fileLines[$lineNum-1] ne "") {
            logMsg($LOG_WARN, "Expected Blank Line");
            logMsg($LOG_WARN, "Verify line ".$lineNum." is blank. Exiting.");
            runExit($exitWarn);
            }
          }
      }
}

#
# Name: runGetParameterDetails
# Func: after verifying HANABackupCustomerDetails, it is now interpreted into usable format
#

sub runGetParameterDetails {

  my $k = $detailsStart;
  #HANA Server Name
  my $lineNum;
  $lineNum = $k-5;
  if (substr($fileLines[$lineNum-1],0,1) ne "#") {
    @strSnapSplit = split(/:/, $fileLines[$lineNum-1]);
  } else {
    logMsg($LOG_WARN,"Cannot skip HANA Server Name. It is a required field");
    runExit($exitWarn);
  }
  if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
    $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
    $strPrimaryHANAServerName = $strSnapSplit[1];
    logMsg($LOG_INFO,"HANA Server Name: ".$strPrimaryHANAServerName);
  }

  undef @strSnapSplit;
  #HANA SERVER IP Address
  $lineNum = $k-4;
  if (substr($fileLines[$lineNum-1],0,1) ne "#") {
    @strSnapSplit = split(/:/, $fileLines[$lineNum-1]);
  } else {
    logMsg($LOG_WARN,"Cannot skip HANA Server IP Address. It is a required field");
    runExit($exitWarn);
  }
  if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
    $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
    $strPrimaryHANAServerIPAddress = $strSnapSplit[1];
    logMsg($LOG_INFO,"HANA Server IP Address: ".$strPrimaryHANAServerIPAddress);
  }

  undef @strSnapSplit;

  for my $i (0 .. $numSID) {

    my $j = ($detailsStart+$i*9);
    undef @strSnapSplit;

    if (!$fileLines[$j]) {
      next;
    }

    #SID
    if (substr($fileLines[$j],0,1) ne "#") {
      @strSnapSplit = split(/:/, $fileLines[$j]);
    } else {
      $arrCustomerDetails[$i][0] = "Skipped";
      logMsg($LOG_INFO,"SID".($i+1).": ".$arrCustomerDetails[$i][0]);
    }
    if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
      $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
      $arrCustomerDetails[$i][0] = lc $strSnapSplit[1];
      logMsg($LOG_INFO,"SID".($i+1).": ".$arrCustomerDetails[$i][0]);
    } elsif (!$strSnapSplit[1] and !$arrCustomerDetails[$i][0]) {
            $arrCustomerDetails[$i][0] = "Omitted";
            logMsg($LOG_INFO,"SID".($i+1).": ".$arrCustomerDetails[$i][0]);

    }

    #Storage Backup Name
    if (substr($fileLines[$j+2],0,1) ne "#") {
    @strSnapSplit = split(/:/, $fileLines[$j+2]);
    } else {
      $arrCustomerDetails[$i][1] = "Skipped";
      logMsg($LOG_INFO,"Storage Backup Name: ".$arrCustomerDetails[$i][1]);
    }
    if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
      $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
      $arrCustomerDetails[$i][1] = lc $strSnapSplit[1];
      logMsg($LOG_INFO,"Storage Backup Name: ".$arrCustomerDetails[$i][1]);
    } elsif (!$strSnapSplit[1] and !$arrCustomerDetails[$i][1]) {
            $arrCustomerDetails[$i][1] = "Omitted";
            logMsg($LOG_INFO,"Storage Backup Name: ".$arrCustomerDetails[$i][1]);

    }

    #Storage IP Address
    if (substr($fileLines[$j+3],0,1) ne "#") {
      @strSnapSplit = split(/:/, $fileLines[$j+3]);
    } else {
      $arrCustomerDetails[$i][2] = "Skipped";
      logMsg($LOG_INFO,"Storage Backup Name: ".$arrCustomerDetails[$i][2]);
    }
    if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
      $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
      $arrCustomerDetails[$i][2] = $strSnapSplit[1];
      logMsg($LOG_INFO,"Storage IP Address: ".$arrCustomerDetails[$i][2]);
    } elsif (!$strSnapSplit[1] and !$arrCustomerDetails[$i][2]) {
            $arrCustomerDetails[$i][2] = "Omitted";
            logMsg($LOG_INFO,"Storage Backup Name: ".$arrCustomerDetails[$i][2]);

    }

    #HANA Instance Number
    if (substr($fileLines[$j+5],0,1) ne "#") {
      @strSnapSplit = split(/:/, $fileLines[$j+5]);
    } else {
      $arrCustomerDetails[$i][3] = "Skipped";
      logMsg($LOG_INFO,"HANA Instance Number: ".$arrCustomerDetails[$i][3]);
    }
    if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
      $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
      $arrCustomerDetails[$i][3] = $strSnapSplit[1];
      logMsg($LOG_INFO,"HANA Instance Number: ".$arrCustomerDetails[$i][3]);
    } elsif (!$strSnapSplit[1] and !$arrCustomerDetails[$i][3]) {
            $arrCustomerDetails[$i][3] = "Omitted";
            logMsg($LOG_INFO,"HANA Instance Number: ".$arrCustomerDetails[$i][3]);

    }

    #HANA User name
    if (substr($fileLines[$j+6],0,1) ne "#") {
      @strSnapSplit = split(/:/, $fileLines[$j+6]);
    } else {
      $arrCustomerDetails[$i][4] = "Skipped";
      logMsg($LOG_INFO,"HANA Instance Number: ".$arrCustomerDetails[$i][4]);
    }
    if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
      $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
      $arrCustomerDetails[$i][4] = uc $strSnapSplit[1];
      logMsg($LOG_INFO,"HANA Userstore Name: ".$arrCustomerDetails[$i][4]);
    } elsif (!$strSnapSplit[1] and !$arrCustomerDetails[$i][4]) {
            $arrCustomerDetails[$i][4] = "Omitted";
            logMsg($LOG_INFO,"HANA Instance Number: ".$arrCustomerDetails[$i][4]);

    }
  }
}

#
# Name: runVerifySIDDetails
# Func: ensures that all necessary details for an SID entered are provided and understood.
#

sub runVerifySIDDetails {


NUMSID:    for my $i (0 ... $numSID) {
      my $checkSID = 1;
      my $checkBackupName = 1;
      my $checkIPAddress = 1;
      my $checkHANAInstanceNumber = 1;
      my $checkHANAUserstoreName = 1;

      for my $j (0 ... 4) {
        if (!$arrCustomerDetails[$i][$j]) { last NUMSID; }
      }

      if ($arrCustomerDetails[$i][0] eq "Omitted") {
          $checkSID = 0;
      }
      if ($arrCustomerDetails[$i][1] eq "Omitted") {
          $checkBackupName = 0;
      }
      if ($arrCustomerDetails[$i][2] eq "Omitted") {
          $checkIPAddress = 0;
      }
      if ($arrCustomerDetails[$i][3] eq "Omitted") {
          $checkHANAInstanceNumber = 0;
      }
      if ($arrCustomerDetails[$i][4] eq "Omitted") {
          $checkHANAUserstoreName = 0;
      }

      if ($checkSID eq 0 and $checkBackupName eq 0 and $checkIPAddress eq 0 and $checkHANAInstanceNumber eq 0 and $checkHANAUserstoreName eq 0) {
        next;
      } elsif ($checkSID eq 1 and $checkBackupName eq 1 and $checkIPAddress eq 1 and $checkHANAInstanceNumber eq 1 and $checkHANAUserstoreName eq 1) {
        next;
      } else {
            if ($checkSID eq 0) {
              logMsg($LOG_WARN,"Missing SID".($i+1)." Exiting.");
            }
            if ($checkBackupName eq 0) {
              logMsg($LOG_WARN,"Missing Storage Backup Name for SID".($i+1)." Exiting.");
            }
            if ($checkIPAddress eq 0) {
              logMsg($LOG_WARN,"Missing Storage IP Address for SID".($i+1)." Exiting.");
            }
            if ($checkHANAInstanceNumber eq 0) {
              logMsg($LOG_WARN,"Missing HANA Instance User Name for SID".($i+1)." Exiting.");
            }
            if ($checkHANAUserstoreName eq 0) {
              logMsg($LOG_WARN,"Missing HANA Userstore Name for SID".($i+1)." Exiting.");
            }
            runExit($exitWarn);
        }
    }
}

#
# Name: logMsg()
# Func: Print out a log message based on the configuration.  The
#       way messages are printed are based on the type of verbosity,
#       debugging, etc.
#


sub logMsg
{
	# grab the error string
	my ( $errValue, $msgString ) = @_;

	my $str;
	if ( $errValue & $LOG_INFO ) {
		$str .= "$msgString";
		$str .= "\n";
		if ( $verbose != 0 ) {
			print $str;
		}
	push (@arrOutputLines, $str);
	}

	if ( $errValue & $LOG_WARN ) {
		$str .= "WARNING: $msgString\n";
		$exitWarn = 1;
    print color('bold red');
    print $str;
    print color('reset');
	}
}


#
# Name: runExit()
# Func: Exit the script, but be sure to print a report if one is
#       requested.
#
sub runExit
{
	$exitCode = shift;
	if ( ( $exitWarn != 0 ) && ( !$exitCode ) ) {
		$exitCode = $ERR_WARN;
	}

	# print the error code message (if verbose is selected)
	if ( $verbose != 0 ) {
		logMsg( $LOG_INFO, "Exiting with return code: $exitCode" );
    if ($exitCode eq 0) {

      print color ('bold green');
      logMsg( $LOG_INFO, "Command completed successfully." );
      print color ('reset');
    }
    if ($exitCode eq 1) {

      print color ('bold red');
      logMsg( $LOG_INFO, "Command failed. Please check screen output or created logs for errors." );
      print color ('reset');
    }
  }
  runPrintFile();
  exit( $exitCode );
}
#
# Name: runShellCmd
# Func: Run a command in the shell and return the results.
#
sub runShellCmd
{
	#logMsg($LOG_INFO,"inside runShellCmd");
	my ( $strShellCmd ) = @_;
	return( `$strShellCmd 2>&1` );
}


#
# Name: runSSHCmd
# Func: Run an SSH command.
#
sub runSSHCmd
{
	#logMsg($LOG_INFO,"inside runSSHCmd");
	my ( $strShellCmd ) = @_;
	return(  `"$sshCmd" -l $strUser $strSVM 'set -showseparator ","; $strShellCmd' 2>&1` );
}

#
# Name: runCheckStorageSnapshotStatus()
# Func: Verifies access to storage and obtains list of volumes
#
sub runCheckStorageSnapshotStatus
{
    print color('bold green');
    logMsg($LOG_INFO, "**********************Checking access to Storage**********************");
    print color('reset');
      my $strStorageSnapshotStatusCmd = "volume show -type RW -fields volume";
      my @out = runSSHCmd( $strStorageSnapshotStatusCmd );
			if ( $? ne 0 ) {
					logMsg( $LOG_WARN, "Storage check status command '" . $strStorageSnapshotStatusCmd . "' failed: $?" );
          logMsg( $LOG_WARN, "Please check the following:");
          logMsg( $LOG_WARN, "Was publickey sent to Microsoft Service Team?");
          logMsg( $LOG_WARN, "If passphrase reqested while using ssh-keygen, publickey must be re-created and passphrase must be left blank for both entries");
          logMsg( $LOG_WARN, "Ensure correct IP address was entered in HANABackupCustomerDetails.txt");
          logMsg( $LOG_WARN, "Ensure correct Storage backup name was entered in HANABackupCustomerDetails.txt");
          logMsg( $LOG_WARN, "Ensure that no modification in format HANABackupCustomerDetails.txt like additional lines, line numbers or spacing");
					logMsg( $LOG_WARN, "******************Exiting Script*******************************" );
          runExit($exitWarn);
				} else {
					logMsg( $LOG_INFO, "Storage Snapshot Access successful." );
			}

}

#
# Name: runGetVolumeLocations()
# Func: Gets list of volumes that correspond to customer entered agrument for SID
#

sub runGetVolumeLocations
{
  print color('bold green');
  logMsg($LOG_INFO, "**********************Getting list of volumes that match HANA instance specified**********************");
	logMsg( $LOG_INFO, "Collecting set of volumes hosting HANA matching pattern *$strHANASID* ..." );
  print color('reset');
  my $strSSHCmd = "volume show -volume *".$strHANASID."* -volume !*log_".$strHANASID."* -type RW -fields volume";
	my @out = runSSHCmd( $strSSHCmd );
	if ( $? ne 0 ) {
		logMsg( $LOG_WARN, "Running '" . $strSSHCmd . "' failed: $?" );
    logMsg( $LOG_WARN, "Please verify $strHANASID is the correct SID.");
    logMsg( $LOG_WARN, "Otherwise, please try again in a few minutes");
    logMsg( $LOG_WARN, "If issue persists, please contact Microsoft Operations for assistance.");
    runExit($exitWarn);
  } else {
		logMsg( $LOG_INFO, "Volume show completed successfully." );
	}
	my $i=0;
	my $listnum = 0;
	my $count = $#out - 1;
	for my $j (0 ... $count ) {
		$listnum++;
		next if ( $listnum <= 3 );
		chop $out[$j];
		my @arr = split( /,/, $out[$j] );

			my $name = $arr[$#arr-1];
			#logMsg( $LOG_INFO, $i."-".$name );
			if (defined $name) {
				logMsg( $LOG_INFO, "Adding volume $name to the snapshot list." );
				$snapshotLocations[$i][0]= $name;

			}
	$i++;
	}
}

#
# Name: runGetSnapshotsByVolume()
# Func: Gets list of snapshots for each volume matching SID
#

sub runGetSnapshotsByVolume
{
print color('bold green');
logMsg($LOG_INFO, "**********************Adding list of snapshots to volume list**********************");
print color('reset');
		my $i = 0;

		logMsg( $LOG_INFO, "Collecting set of snapshots for each volume hosting HANA matching pattern *$strHANASID* ..." );
		for my $i (0 .. $#snapshotLocations) {
				my $j = 0;
				my $strSSHCmd = "volume snapshot show -volume $snapshotLocations[$i][0] -fields snapshot";
				my @out = runSSHCmd( $strSSHCmd );
				if ( $? ne 0 ) {
						logMsg( $LOG_WARN, "Running '" . $strSSHCmd . "' failed: $?" );
            logMsg( $LOG_WARN, "Please try again in a few minutes");
            logMsg( $LOG_WARN, "If issue persists, please contact Microsoft Operations for assistance.");
            runExit($exitWarn);
				}
				my $listnum = 0;
				$j=1;
				my $count = $#out-1;
				foreach my $k ( 0 ... $count ) {
							#logMsg($LOG_INFO, $item)
							$j++;
							$listnum++;
							if ( $listnum <= 4) {
								chop $out[$k];
								$j=1;
							}
							my @strSubArr = split( /,/, $out[$k] );
							my $strSub = $strSubArr[$#strSubArr-1];
							$snapshotLocations[$i][$j] = $strSub;
				}

		}

}

#
# Name: runRemoveTestStorageSnapshot()
# Func: removes temp snapshot created while running testStorageSnapshotConnection
#

sub runRemoveTestStorageSnapshot
{
print color('bold green');
logMsg($LOG_INFO, "**********************Deleting existing testStorage snapshots**********************");
print color('reset');
	for my $i (0 ... $#snapshotLocations) {
    for my $k (1 ... $#{$snapshotLocations[$i]}) {
      # let's make sure the snapshot is there first
  		my $checkSnapshotResult = runCheckIfSnapshotExists( $snapshotLocations[$i][0], $snapshotLocations[$i][$k]);
  		if ($checkSnapshotResult eq "0") {
  			logMsg( $LOG_INFO, "Temp snapshot $strSnapshotPrefix\.temp does not exist on $snapshotLocations[$i][0]." );
  		} else {
  			# delete the temp snapshot
  			logMsg($LOG_INFO, "Removing temp snapshot $strSnapshotPrefix\.temp on $snapshotLocations[$i][0] on SVM $strSVM ..." );
  			logMsg($LOG_INFO, $checkSnapshotResult);
  			my $strSSHCmd = "volume snapshot delete -volume $snapshotLocations[$i][0] -snapshot $checkSnapshotResult";

  			my @out = runSSHCmd( $strSSHCmd );
  			if ( $? ne 0 ) {
  				logMsg( $LOG_WARN, "Running '" . $strSSHCmd . "' failed: $?" );
          logMsg( $LOG_WARN, "Please try again in a few minutes");
          logMsg( $LOG_WARN, "If issue persists, please contact Microsoft Operations for assistance.");
        }
      }
    }
  }
}

#
# Name: runCheckIfSnapshotExists()
# Func: scans through list of snapshots to see if a match is found on a given volume
#

sub runCheckIfSnapshotExists
{
	my $volName = shift;
	my $snapName = shift;
	my $tempSnapName = "";
	logMsg( $LOG_INFO, "Checking if snapshot $snapName exists for $volName on SVM $strSVM ..." );

	my $listnum = 0;
	#checking to make sure volume in $volName exists in the array
	for my $i (0 .. $#snapshotLocations) {
		if ($volName eq $snapshotLocations[$i][0]){
			logMsg( $LOG_INFO, "$volName found." );
			#with the volume found, each snapshot associated with that volume is now examxined
			my $aref = $snapshotLocations[$i];
			for my $j (0 .. $#{$aref} ) {
#        logMsg($LOG_INFO,"snapshotLocations[".$i."][".$j."]: ".$snapshotLocations[$i][$j]);
        if ($j ne 0) {
          @strSnapSplit = split(/\./, $snapshotLocations[$i][$j]);
        } else {
          next;
        }
        if ($strSnapSplit[2] eq "temp") {
				      $tempSnapName = $snapshotLocations[$i][$j];
        }
				if ( $tempSnapName eq $snapName ) {
					logMsg( $LOG_INFO, "Snapshot $snapName on $volName found." );
					return($snapshotLocations[$i][$j]);
				}
			}
		}
	}
	logMsg( $LOG_INFO, "Snapshot $snapName on $volName not found." );
	return( "0" );

}

#
# Name: displayArray()
# Func: displays the list of snapshots by volume
#

sub displayArray
{
print color('bold green');
logMsg($LOG_INFO, "**********************Displaying Snapshots by Volume**********************");
print color('reset');
         for my $i (0 .. $#snapshotLocations) {
                my $aref = $snapshotLocations[$i];
                for my $j (0 .. $#{$aref} ) {

                         logMsg($LOG_INFO,$snapshotLocations[$i][$j]);
                 }
         }

}

#
# Name: runPrintFile()
# Func: Copies output of logs and warnings to log file
#

sub runPrintFile
{
	my $myLine;
	my $date = localtime->strftime('%Y-%m-%d_%H%M');
	$outputFilename = "removeTestStorage.$date.txt";
	my $existingdir = './statusLogs';
	mkdir $existingdir unless -d $existingdir; # Check if dir exists. If not create it.
	open my $fileHandle, ">>", "$existingdir/$outputFilename" or die "Can't open '$existingdir/$outputFilename'\n";
  print color('bold green');
  logMsg($LOG_CRIT, "Log file created at ".$existingdir."/".$outputFilename);
  print color('reset');
  foreach $myLine (@arrOutputLines) {
		print $fileHandle $myLine;
	}
	close $fileHandle;
}

#
# Name: runClearVolumeLocations()
# Func: Clears volume array before obtaining details for next SID
#

sub runClearVolumeLocations
{
  print color('bold green');
  logMsg($LOG_INFO, "**********************Clearing volume list**********************");
  print color('reset');
  undef @volLocations;
}

#
# Name: runClearSnapshotLocations()
# Func: Clears Snapshot array before obtaining details for next SID
#

sub runClearSnapshotLocations
{
  print color('bold green');
  logMsg($LOG_INFO, "**********************Clearing snapshot list**********************");
  print color('reset');
  undef @snapshotLocations;
}

##### --------------------- MAIN CODE --------------------- #####
print color('bold green');
logMsg($LOG_INFO,"Executing removeTestStorageSnapshot Script, Version $version");
print color('reset');
#read and store each line of HANABackupCustomerDetails to fileHandle
runOpenParametersFiles();

#verify each line is expected based on template, otherwise throw error.
runVerifyParametersFile();

#add Parameters to usable array customerDetails
runGetParameterDetails();

#verify all required details entered for each SID
runVerifySIDDetails();

for my $i (0 .. $numSID) {

  #logMsg($LOG_INFO,"arrCustomerDetails[".$i."][0]: ". $arrCustomerDetails[$i][0]);
  if ($arrCustomerDetails[$i][0] and ($arrCustomerDetails[$i][0] ne "Skipped" and $arrCustomerDetails[$i][0] ne "Omitted")) {
     $strHANASID = $arrCustomerDetails[$i][0];
     print color('bold blue');
     logMsg($LOG_INFO, "Checking Snapshot Status for $strHANASID");
     print color('reset');
     $strUser = $arrCustomerDetails[$i][1];
     $strSVM = $arrCustomerDetails[$i][2];

  } else {
    logMsg($LOG_INFO, "No data entered for SID".($i+1)."  Skipping!!!");
    next;
  }



  # execute the HANA create snapshot command
  runCheckStorageSnapshotStatus();

  # get volume(s) to take a snapshot of based on HANA instance provided
  runGetVolumeLocations();
  runGetSnapshotsByVolume();

  displayArray();
  # execute a storage snapshot of empty volume to create values
  runRemoveTestStorageSnapshot();

  runClearVolumeLocations();
  runClearSnapshotLocations();

  runGetVolumeLocations();
  runGetSnapshotsByVolume();

  displayArray();

  runClearSnapshotLocations();
  runClearVolumeLocations();

}

# if we get this far, we can exit cleanly
logMsg( $LOG_INFO, "Command completed successfully." );




# time to exit
runExit( $ERR_NONE );
