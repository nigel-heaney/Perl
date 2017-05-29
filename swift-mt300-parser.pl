#!/usr/bin/perl
# Name: swift-mt300-parser.pl
# Description:  Examine all 3xx files and parse for multiple records and split. 
# 				
# Author: Nigel Heaney
# Version: 0.1 - 05/11 Initial Build
#

use strict;
use File::Copy;

# Globals.
my $appname = "SWIFT MT300 Record Parser v0.1\n\n";
my $prepickupdir = "/tmp/prepickup/";
my $archivepickupdir = "/tmp/archive/";
my $pickupdir = "/tmp/pickup/";

my $pickup_fileext = "*.3xx";
my $counter = 1;
my $fullfilename = "";
my @files;
my $transfile;
my $check;
my $post;
my $newfh;

my $sec;
my $min;
my $hr;
my $mday;
my $mon;
my $yr;
my $dirdate;

######################################################################
# MAIN
print "$appname";
print "Begin Time: " . scalar localtime() . "\n";
($sec,$min,$hr,$mday,$mon,$yr) = localtime();
$yr += 1900; 
$mon++;
$dirdate=sprintf("%04d%02d%02d",$yr, $mon, $mday);
print "$dirdate";
opendir(DIR, $prepickupdir);
@files=grep(/\.3xx/, readdir(DIR)); 
print $#files+1 . " files to be processed...\n\n";
foreach $transfile (@files){
	print "Processing - ". $transfile;
	$fullfilename = $prepickupdir . $transfile;
	# lets copy the original to archive_pickup as it needs tobe done regardless
	copy2archive($fullfilename,$archivepickupdir);
	$check = check4multiple_records($fullfilename);
	if ($check == 1){
		print " - [MULTIPLE]\n";
		parsefile($fullfilename);
		#unlink $fullfilename or die "Deletion failed: $!";
	} else {
		#nothing todo, move the file to the pickup directory
		print " - [SINGLE]\n";
		move($fullfilename,$pickupdir) or die "Move failed: $!";
	}
} 
print "End Time: " . scalar localtime();
exit(0);


######################################################################
sub copy2archive {
	# takes 2 arguments, 1=filename, 2=destination and then copy to dest+3xxedir
	my $fname = $_[0];
	my $destname = $_[1];
	my $newdestname;
	$newdestname = $archivepickupdir . $dirdate . "/";
	if ( -d $newdestname){
		copy($fname,$newdestname) or die "Copying failed: $!";
	}else{
		mkdir($newdestname) or die "Create archive directory failed: $!";
		copy($fname,$newdestname) or die "Copying failed: $!";
	}
}

sub parsefile {
	#walk through file and break each transaction apart which start with { and terminates with }@
	my $fname = $_[0];
	my $fullfname = $fname;		#$prepickupdir . $fname; 
	my $fh, $newfh;
	my $cnt = 1;
	my $newfname = "";
	my $pre, $post;
	open $fh, "< $fullfname" or die "ERROR: Opening $fullfname $!";
	#generate new filename and open it
	$newfname = $fullfname;
	$newfname =~ s/\.3xx$/_$cnt.3xx/;
	open $newfh, ">> $newfname" or die "ERROR: Opening $newfname $!";
	#print "$newfname\n";
	while (<$fh>) {
		# if current line contains the terminator string then we wrtie out last record part and roll onto the next filesplit
		if (/\cC+/) {
				#if line contains "" then we have the end of the record and the beginning of another, if its }@ then we are at the end.
				if (/\cC.*\cA/) {
					# close off current record and begin the next
					($pre, $post) = split /\cC.*\cA/,$_;
					$pre = $pre . "\cC";  #add terminator back in
					$post = "\cA" . $post; #add initiator back in
					#print "$pre|||$post\n";
					print $newfh $pre;
					close $newfh;
					# lets copy the files to archive and pickup now we are done
					copy2archive($newfname,$archivepickupdir);
					move($newfname,$pickupdir) or die "Move failed: $!";
					# spawn next record file...
					$cnt++;
					$newfname = $fullfname;
					$newfname =~ s/\.3xx$/_$cnt.3xx/;
					open $newfh, ">> $newfname" or die "ERROR: Opening $newfname $!";
					# now lets write out the post so the new file is correct
					print $newfh $post;
					
				}else{
					# we are at end so wrap things up
					print $newfh $_;
					close $newfh;
					# lets copy the files to archive and pickup now we are done
					copy2archive($newfname,$archivepickupdir);
					move($newfname,$pickupdir) or die "Move failed: $!";
				}
		}else{
			# otherwise write line out to current newfile
			print $newfh $_;

		}
	}
	close $fh;
	close $newfh;
	return(0);
}

sub check4multiple_records {
	# pass through filename and check to see if file needs tobe worked on
	# return 0 single record or 1 multiple records detected
	# search pattern is "}@{" where @ is considered the record terminator
	my $fname = $_[0];
	my $fh;
#	$filename =~ s/\\/\\\\/g;
	open $fh, "< $fname" or die "ERROR: Opening $fname";
	while (<$fh>) {
		if (/\cC.*\cA/) {
			# multiple records detected, so return to caller with this status
			close $fh;
			return(1);
		}
	}
	close $fh;
	# nothing found means single record in file
	return(0);
}


