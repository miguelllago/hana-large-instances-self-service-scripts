#!/usr/bin/perl -w
#
# Copyright (C) 2017 Microsoft, Inc. All rights reserved.
# Specifications subject to change without notice.
#
# Name: azure_hana_snapshot_details.pl
#Version: 3.0
#Date 01/27/2018

use strict;
use warnings;
use Time::Piece;
use Date::Parse;
use Time::HiRes;
use Term::ANSIColor;
#Usage:  This script provides details on all storage snapshots that currently exist within a customer's environment.

#number of allowable SIDs. Number entered is one less than actual.. i.e if allowing 4 SIDs, then 3 is entered
my $numSID = 9;
my $detailsStart = 13;
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
# $numKeep            - The number of snapshots to keep
# $sshCmd             - The default SSH command to use
# $verbose            - Whether to be more verbose (or not)
# $strSVM             - The SVM (tenant) hosting the SAP HANA environment, by IP address
# $strUser            - The username to log into the SVM(s) with
# $strSnapshotPrefix  - The prefix name of the snapshot (number appended). i.e. Customer, Hourly, etc.
# $strHANACreateCmd   - The command to run to create the HANA snapshot
# $strHANADeleteCmd   - The command to run to delete the HANA snapshot
# $strHANAAdmin 			- The username on the HANA instance created with HANA backup credentials, typically SCADMINXX where XX is HANA instance number.
# $strHDBSQLPath			- Customer path to where application hdbsql exists
# $strHANAInstance 		- The HANA instance that requires snapshots to be created.  It looks for matching patterns in the volumes of the SVM that are RW
my @arrOutputLines;
my @fileLines;
my @strSnapSplit;
my @arrCustomerDetails;
my $strHANABackupID;
my $strExternalBackupID;
my $strHANAServerName;
my $strHANAServerIPAddress;
my $strHANAInstance;
my $filename = "HANABackupCustomerDetails.txt";


my $strUser;
my $strSVM;

#open the customer-based text file to gather required details
sub runOpenParametersFiles {
  open(my $fh, '<:encoding(UTF-8)', $filename)
    or die "Could not open file '$filename' $!";

  chomp (@fileLines=<$fh>);
  close $fh;
}

sub runVerifyParametersFile {

  my $k = $detailsStart;
  my $lineNum;
  $lineNum = $k-3;
  my $stringServerName = "HANA Server Name:";
  if ($fileLines[$lineNum-1]) {
    if (index($fileLines[$lineNum-1],$stringServerName) eq -1) {
      logMsg($LOG_WARN, "Expected ".$stringServerName);
      logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting");
      exit;
    }
  }


  $lineNum = $k-2;
  my $stringHANAIPAddress = "HANA Server IP Address:";
  if ($fileLines[$lineNum-1]) {
    if (index($fileLines[$lineNum-1],$stringHANAIPAddress) eq -1) {
      logMsg($LOG_WARN, "Expected ".$stringHANAIPAddress);
      logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting");
      exit;
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
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string2 = "SID".($i+1);
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string2) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string2);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string3 = "###Provided by Microsoft Operations###";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string3) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string3);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string4 = "SID".($i+1)." Storage Backup Name:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string4) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string4);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string5 = "SID".($i+1)." Storage IP Address:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string5) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string5);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string6 = "######     Customer Provided    ######";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string6) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string6);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string7 = "SID".($i+1)." HANA instance number:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string7) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string7);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        my $string8 = "SID".($i+1)." HANA HDBuserstore Name:";
        if ($fileLines[$lineNum-1]) {
          if (index($fileLines[$lineNum-1],$string8) eq -1) {
            logMsg($LOG_WARN, "Expected ". $string8);
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            exit;
          }
        }
        $j++;
        $lineNum = $k+$j;
        if ($#fileLines >= $lineNum-1 and $fileLines[$lineNum-1]) {
          if ($fileLines[$lineNum-1] ne "") {
            logMsg($LOG_WARN, "Expected Blank Line");
            logMsg($LOG_WARN, "Verify line ".$lineNum." is correct. Exiting.");
            exit;
            }
          }
      }
}

sub runGetParameterDetails {

  my $k = $detailsStart;
  #HANA Server Name
  my $lineNum;
  $lineNum = $k-3;
  if (substr($fileLines[$lineNum-1],0,1) ne "#") {
    @strSnapSplit = split(/:/, $fileLines[$lineNum-1]);
  } else {
    logMsg($LOG_WARN,"Cannot skip HANA Server Name. It is a required field");
    exit;
  }
  if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
    $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
    $strHANAServerName = $strSnapSplit[1];
    logMsg($LOG_INFO,"HANA Server Name: ".$strHANAServerName);
  }

  undef @strSnapSplit;
  #HANA SERVER IP Address
  $lineNum = $k-2;
  if (substr($fileLines[$lineNum-1],0,1) ne "#") {
    @strSnapSplit = split(/:/, $fileLines[$lineNum-1]);
  } else {
    logMsg($LOG_WARN,"Cannot skip HANA Server IP Address. It is a required field");
    exit;
  }
  if ($strSnapSplit[1] and $strSnapSplit[1] !~ /^\s*$/) {
    $strSnapSplit[1]  =~ s/^\s+|\s+$//g;
    $strHANAServerIPAddress = $strSnapSplit[1];
    logMsg($LOG_INFO,"HANA Server IP Address: ".$strHANAServerIPAddress);
  }

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
            exit;
        }
    }
}

#DO NOT MODIFY THESE VARIABLES!!!!

my $sshCmd = '/usr/bin/ssh';
my $verbose = 1;


my $arrSnapshot = "";
my $outputFilename = "";


# Global parameters
my @snapshotLocations;
my @volLocations;



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

	# exit with our error code
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
# Name: runGetVolumeLocations()
# Func: Get all volumes that belong to the tenant
#
sub runGetVolumeLocations
{

  logMsg($LOG_INFO, "**********************Getting list of all customer volumes**********************");
  my $strSSHCmd = "volume show -volume *".$strHANAInstance."* -type RW -fields volume";
  my @out = runSSHCmd( $strSSHCmd );
	if ( $? ne 0 ) {
		logMsg( $LOG_WARN, "Running '" . $strSSHCmd . "' failed: $?" );
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
				logMsg( $LOG_INFO, "Adding volume $name to the volumes list." );
				push( @volLocations, $name );

			}
	$i++;
	}
}

#
# Name: runGetSnapshotsByVolume()
# Func: Get the list of snapshots for each volume.
#

sub runGetSnapshotsByVolume
{
logMsg($LOG_INFO, "**********************Adding list of snapshots to volume list**********************");
		my $i = 0;

    foreach my $volName ( @volLocations ) {

        my $j = 0;

				my $strSSHCmd = "volume snapshot show -volume $volName -fields snapshot";
				my @out = runSSHCmd( $strSSHCmd );
				if ( $? ne 0 ) {
						logMsg( $LOG_INFO, "Running '" . $strSSHCmd . "' failed: $?" );
            logMsg( $LOG_INFO, "Possible reason: Volume $volName does not contain any snapshots!" );
            next;
        }
        $snapshotLocations[$i][0][0] = $volName;
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
              $snapshotLocations[$i][$j][0] = $strSub;
				}
				$i++;
		}

}

sub runGetSnapshotDetailsBySnapshot
{

  logMsg($LOG_INFO, "**********************Adding snapshot details to snapshot list**********************");


      for my $x (0 .. $#snapshotLocations) {
             my $aref = $snapshotLocations[$x];
             for my $y (1.. $#{$aref} ) {

               Time::HiRes::sleep (0.5+rand(0.5));
               logMsg($LOG_INFO,"Obtaining Snapshot $snapshotLocations[$x][$y][0] details for volume $snapshotLocations[$x][0][0]");
               my $strSSHCmd = "volume snapshot show -volume $snapshotLocations[$x][0][0] -snapshot $snapshotLocations[$x][$y][0] -fields snapshot,size,create-time,comment,snapmirror-label";
  				     my @out = runSSHCmd( $strSSHCmd );

               if ( $? ne 0 ) {
  						         logMsg( $LOG_WARN, "Running '" . $strSSHCmd . "' failed: $?" );
  						          return( 0 );
  				     }
  							my @strSubArr = split( /,/, $out[3] );
                #logMsg($LOG_INFO,$strSubArr);
                my $strSubCreateTime = $strSubArr[$#strSubArr-4];
                my $strSubSize = $strSubArr[$#strSubArr-3];
                my $strSubHanaBackupID = $strSubArr[$#strSubArr-2];
                my $strSubFrequency = $strSubArr[$#strSubArr-1];
                #logMsg($LOG_INFO,"create time: $strSubCreateTime");
                #logMsg($LOG_INFO,"size: $strSubSize");
                #logMsg($LOG_INFO,"HanaBackupID: $strSubHanaBackupID");
                #logMsg($LOG_INFO,"frequency: $strSubFrequency");


                $snapshotLocations[$x][$y][1] = $strSubCreateTime;
                $snapshotLocations[$x][$y][2] = $strSubSize;
                $snapshotLocations[$x][$y][3] = $strSubHanaBackupID;
  		          $snapshotLocations[$x][$y][4] = $strSubFrequency;
              }
            }
}


sub displaySnapshotArray
{
logMsg($LOG_INFO, "**********************Displaying Snapshots by Volume**********************");
         for my $i (0 .. $#snapshotLocations) {
                my $aref = $snapshotLocations[$i];
                for my $j (0 .. $#{$aref} ) {

                         logMsg($LOG_INFO,$snapshotLocations[$i][$j][0]);
                 }
         }

}


sub displaySnapshotArrayDetails
{
logMsg($LOG_INFO, "**********************Displaying Snapshot Details by Volume**********************");
        my $t = 1;


            for my $i (0 .. $#snapshotLocations) {
              print color('bold blue');
              logMsg($LOG_INFO,"**********************************************************");
              logMsg($LOG_INFO,"****Volume: $snapshotLocations[$i][0][0]       ***********");
              logMsg($LOG_INFO,"**********************************************************");
              print color('reset');
              my $strSSHCmd = "volume show -volume $snapshotLocations[$i][0][0] -fields size-used-by-snapshots";
      				my @out = runSSHCmd( $strSSHCmd );
              if ( $? ne 0 ) {
                      logMsg( $LOG_WARN, "Running '" . $strSSHCmd . "' failed: $?" );
                       return( 0 );
              }
              my @strSubArr = split( /,/, $out[3] );
              my $strVolTotalSnapshotSize = $strSubArr[2];

              logMsg($LOG_INFO,"Total Snapshot Size:  ".  $strVolTotalSnapshotSize);
              my $aref = $snapshotLocations[$i];
              for my $j (1 .. $#{$aref} ) {
                      print color('bold green');
                      logMsg($LOG_INFO,"----------------------------------------------------------");
                      logMsg($LOG_INFO,"Snapshot:   $snapshotLocations[$i][$j][0]");
                      logMsg($LOG_INFO,"Create Time:   $snapshotLocations[$i][$j][1]");
                      logMsg($LOG_INFO,"Size:   $snapshotLocations[$i][$j][2]");
                      logMsg($LOG_INFO,"Frequency:   $snapshotLocations[$i][$j][4]");
                      if (defined $snapshotLocations[$i][$j][3]) {
                        logMsg($LOG_INFO,"HANA Backup ID:   $snapshotLocations[$i][$j][3]");
                      }
                      print color('reset');
              }
            }
}



sub runPrintFile
{
	my $myLine;
	my $date = localtime->strftime('%Y-%m-%d_%H%M');
	$outputFilename = "SnapshotDetails.$date.txt";
	my $existingdir = './snapshotLogs';
	mkdir $existingdir unless -d $existingdir; # Check if dir exists. If not create it.
	open my $fileHandle, ">>", "$existingdir/$outputFilename" or die "Can't open '$existingdir/$outputFilename'\n";
	foreach $myLine (@arrOutputLines) {
		print $fileHandle $myLine;


	}
	close $fileHandle;
}

##### --------------------- MAIN CODE --------------------- #####
#read and store each line of HANABackupCustomerDetails to fileHandle
runOpenParametersFiles();

#verify each line is expected based on template, otherwise throw error.
runVerifyParametersFile();

#add Parameters to usable array customerDetails
runGetParameterDetails();

#verify all required details entered for each SID
runVerifySIDDetails();

for my $i (0 .. $numSID) {

  if ($arrCustomerDetails[$i][0] and ($arrCustomerDetails[$i][0] ne "Skipped" and $arrCustomerDetails[$i][0] ne "Omitted")) {
     $strHANAInstance = $arrCustomerDetails[$i][0];
     print color('bold blue');
     logMsg($LOG_INFO, "Checking Snapshot Status for $strHANAInstance");
     print color('reset');
     $strUser = $arrCustomerDetails[$i][1];
     $strSVM = $arrCustomerDetails[$i][2];

  } else {
    logMsg($LOG_INFO, "No data entered for SID".($i+1)."  Skipping!!!");
    next;
  }
  # get volume(s) to take a snapshot of
  runGetVolumeLocations();

  #get snapshots by volume and place into array
  runGetSnapshotsByVolume();
  displaySnapshotArray();

  #get snapshot details for each snapshot found
  runGetSnapshotDetailsBySnapshot();
  displaySnapshotArrayDetails();

  print color('bold green');
  logMsg($LOG_INFO,"----------------------------------------------------------");
  print color('reset');
}
# if we get this far, we can exit cleanly
logMsg( $LOG_INFO, "Command completed successfully." );


runPrintFile();
# time to exit
runExit( $ERR_NONE );
