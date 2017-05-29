#!/usr/bin/perl
#  sshload wrapper - maintain simple txt db with conneciton info to feed putty and winscp, intended to be called from cmd prompt
# e.g  ssh myweb  which will read in the db and call putty passing through authentication, then just maintain a txt db file
#
# Author: Nigel Heaney September 2008+
#
# Version Info:
# 0.1 - initial build,  just list and connect
# 0.2 - add list search ability
#		  add command to insert new servers


my $version = "v0.2";
my $datafile = "C:\\apps\\datafile.db";
my @lastcaptime; 


######################################################################
# MAIN

&parse_cmdline;
exit(2);


######################################################################


# load datafile
sub launch {
	my $junk, $fh, $value, $setting, $c;
	# test if its been initialised
	if (!( -e $datafile)){
		print "ERROR: Config not found...\n\n"; 
		&show_help; exit(1);
	}
	# Load-in config file
	open $fh, "< $datafile" or die "ERROR: Opening config file $datafile...";
	while (<$fh>) {
		next if /^\#|^\n/;
		chomp; $_ = lc;
		($tag, $host,$user,$pwd) = split /,/,$_;
		if ($tag eq $v) {
			#print "$v|$tag|$host|$user|$pwd\n";
			print "ssh-load:  connecting to $tag ($host)";
			exec("putty  -load hpserver -l $user -pw $pwd -ssh $host");
			exit(0);
		}
	}
	close $fh;
}

# list servers
sub listservers {
	my $junk, $fh, $value, $setting, $c, $search;
	$search = shift(@ARGV);
	# test if its been initialised
	if (!( -e $datafile)){
		print "ERROR: Config not found...\n\n"; 
		&show_help; exit(1);
	}
	# Load-in config file
	open $fh, "< $datafile" or die "ERROR: Opening config file $datafile...";
	print "TAG 		     HOST\n";
	while (<$fh>) {
		next if /^\#|^\n/;
		chomp; $_ = lc;
		($tag, $host,$user,$pwd) = split /,/,$_;
		if ($search){
			if (($tag =~ $search) || ($host =~ $search)){
				printf "%-20s %-30s %-12s\n", $tag, $host,$user;
			}
		}
		else{
			printf "%-20s %-30s %-12s\n", $tag, $host,$user;
		}
	}
	close $fh;
	exit(0);
}

# add a server to list
sub addserver {
	my $junk, $fh, $value, $setting, $c, $search;
	# test if its been initialised
	if (!( -e $datafile)){
		print "ERROR: Config not found...\n\n"; 
		&show_help; exit(1);
	}
	# Load-in config file
	open $fh, ">> $datafile" or die "ERROR: Opening config file $datafile...";

	print "\nTAG: "; chomp($tag = readline);
	print "HOST: "; chomp($host = readline);
	print "USER: "; chomp($user = readline);
	print "PASSWORD: "; chomp($password = readline);
	
	print $fh "$tag,$host,$user,$password\n";
	exit(0);
}

# Parse Commandline
sub parse_cmdline {
	while ($#ARGV+1) {
		$v = shift(@ARGV);
		if (($v eq "-h") || ($v eq "--help")) {
				&show_help; exit(0);
		} elsif (($v eq "-l") || ($v eq "--list")) { 
				&listservers; exit(0);
		} elsif (($v eq "-a") || ($v eq "--add")) { 
				&addserver; exit(0);
		} else {
				&launch;
				# if subroutine returns here its not found anything,  
		}
	}
	&show_help; exit(0);
}

# Show command usage
sub show_help {
print <<TEXT;
Usage: sshload <Server Tag Name>

	-l | --list <search>		: Server DB
	-h | --help					: This Message 

TEXT

}

