#!/usr/bin/perl
# Bindstat v2.x - process rndc stats and create/maintain averages on hourly/second usage.
#                 Also will have the ability to log dsata RRDTool and produce graphs.
#
# Author: Nigel Heaney September 2008
#
# Version Info:
# 2.0.0 - Initial build, no rrd support
# 2.0.1 - add log data, some tidying up
# 2.0.2 - add showlog 
# 2.0.3 - fixed av bug by storing total q for each hour rather than av
# 2.0.4 - fix av bug
# 2.0.5 - created refresh option to facilitate time restricted captures. Useful running weekdays only etc.
# 2.0.5.1 - fixed stats div 0 error
# 2.0.5.2 - add reset option
                
#Globals
my $version = "v2.0.5.2";
my $datalocation  = "/var/bindstat/";
my $cfgfile       = $datalocation . "bindstat.conf";
my $statsfile     = $datalocation . "bindstat.data";
my $rrddbfile     = $datalocation . "bindstat.rrd";
my $logfile           = $datalocation . "bindstat.log";
my $rndclocation  = "/usr/sbin/rndc";
my $rndcstatsfile = "/tmp/named.stats";
my $lastcount,$lasttime,$warnenabled,$warnthreshold,$logdata,$logrrd,$ntime,$sec,$min,$hr,$mday,$mon,$yr,$total, $count, $now, @cdata;
my @avhr = @samples = @lastcaphr = @lastcaptime = qw('0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'); 


######################################################################
# MAIN

print "BindStat $version - Collate and store RNDC stats\n\n";
$ntime = time;
&parse_cmdline;
exit(2);


######################################################################

# Display log file
sub show_log {
        my $i, $x, $avsec, $lastsec, $avplot, $avmax = 0, $scale, $avday = $lastday = 0;
        print "      DATE          SUCCESS   REF      NXRRSET   NXDOMAIN RECURSION  FAILURE  Q/Hr TOTAL\n";
        open $fh, "< $logfile" or die "ERROR: Could not open file $logfile... $!";
        while (<$fh>) {
                next if /^\#|^\n/;
                chomp;
                ($ltime,$success,$ref,$nxrrset,$nxdomain,$recursion,$failure,$lsample) = split /,/,$_;
                ($sec,$min,$hr,$mday,$mon,$yr) = localtime($ltime);
                printf "%02d-%02d-%02d %02d:%02d:%02d  ", $mday,$mon,$yr % 100,$hr,$min,$sec;
                printf "%-10d %-8d %-8d %-8d %-10d %-8d  %-4d\n",$success,$ref,$nxrrset,$nxdomain,$recursion,$failure,$lsample;
                }
        close $fh;
}

# Display stats
sub show_stats {
        my $lavhr, $i, $x, $s, $avsec, $lastsec, $avplot, $avmax = 0, $scale, $avday = $lastday = 0;
        print "hr  av/hr     last/hr  av/sec last/sec    last capture      Av Histogram\n";
        for($i = 0; $i < 24; $i++){
                next if $samples[$i] == 0;
                if (($avhr[$i] / $samples[$i]) > $avmax) {
                        $avmax = int($avhr[$i] / $samples[$i]);
                }
        }
        $scale = $avmax / 15;
        for($i = 0; $i < 24; $i++){
                ($sec,$min,$hr,$mday,$mon,$yr) = localtime($lastcaptime[$i]);
                if ( $samples[$i] == 0 ){
                        $lavhr = $avhr[$i];
						$avsec = 0;
						$lastsec = 0;
				} else {
						$avsec = int(($avhr[$i] / $samples[$i]) / 3600);
						$lastsec = int($lastcaphr[$i] /3600);
                        $lavhr = int($avhr[$i] / $samples[$i]);
                }
                printf "%02d  %-08d  %-08d  %-04d  %-04d     ", $i, $lavhr, $lastcaphr[$i],$avsec, $lastsec;
                printf "%02d-%02d-%02d %02d:%02d:%02d  ", $mday,$mon,$yr % 100,$hr,$min,$sec;
                if (($lavhr > 0) && ($scale > 0)){
                        $avplot = int($lavhr / $scale);
                        for($x = 0; $x < $avplot; $x++){
                                print "-";
                        }
                #       print "\n avmax: $avmax | avplot: $avplot | lavhr = $lavhr | scale: $scale\n";
                }
                $avday += $avhr[$i];
                $lastday += $lastcaphr[$i];
                print "\n";
        }
        &rndcload;
        print "\nQueries per Day (Average)      : " . $avday . "\nQueries per Day (Last Captured): " . $lastday . "\n\n";
        $x = $total - $lastcount;
        print $total - $lastcount . " Queries have occured in the last " . ($ntime - $lasttime)  . " Seconds...\n"
}


# Read config sub
sub load_config {
    my $junk, $fh, $value, $setting, $c;
    # test if its been initialised
    if (!(  -d $datalocation) || !( -e $cfgfile)){
        print "ERROR: Config not found...Please use --initialise option and create config \n       and work area.\n\n"; 
        &show_help; exit(1);
    }
    # Load-in config file
    open $fh, "< $cfgfile" or die "ERROR: Opening config file $cfgfile...";
    while (<$fh>) {
                        next if /^\#|^\n/ | !/=/;
                        chomp; $_ = lc;
                        ($setting,$value) = split /=/,$_;
                        if ($value =~ /#/) {
                                ($value,$junk) = split /\#/,$value; $value =~ s/\s*$//;
                        }
                        if ($setting eq "logdata"){ $logdata = 0; $logdata = 1 if ($value eq "yes"); }
                        if ($setting eq "logrrd"){ $logrrd = 0; $logrrd = 1 if ($value eq "yes"); }
                        if ($setting eq "warnenabled"){ $warnenabled = 0; $warnenabled = 1 if ($value eq "yes"); }
                        if ($setting eq "warnthreshold"){ $warnthreshold = 0; $warnthreshold = $value; }
                }
        close $fh;
        # Load-in stats data...
        open $fh, "< $statsfile" or die "ERROR: Could not create config file $statsfile... $!";
        chomp ($lastcount = <$fh>);
        chomp ($lasttime = <$fh>);
        for ($c=0;$c <24;$c++){
                chomp($value = <$fh>);
                ($avhr[$c],$samples[$c],$lastcaphr[$c],$lastcaptime[$c]) = split /\,/,$value;
                #print "$c|" . @avhr[$c] . "|" . @samples[$c] . "|" . $lastcaphr[$c] . "|" . $lastcaptime[$c] . "|\n";
        }
  close $fh;
}

# Parse Commandline
sub parse_cmdline {
        while ($#ARGV+1) {
                $v = shift(@ARGV);
                if (($v eq "-i") || ($v eq "--initialise")) {
                        &initialise; exit(0);
                } elsif (($v eq "-c") || ($v eq "--capture")) {
                        &load_config; &capture; exit(0);
                } elsif (($v eq "-s") || ($v eq "--stats")) { 
                        &load_config; &show_stats; exit(0);
                } elsif (($v eq "-g") || ($v eq "--graph")) {
                        &load_config; print "Not Implemented, Coming Soon...\n"; exit(0);
                } elsif (($v eq "-h") || ($v eq "--help")) {
                        &show_help; exit(0);
                } elsif (($v eq "-l") || ($v eq "--showlog")) {
                        &show_log; exit(0);
                } elsif (($v eq "-r") || ($v eq "--refresh")) {
                        &load_config; &refresh; exit(0);
                } elsif (($v eq "-0") || ($v eq "--reset")) {
                        &reset; exit(0);
                } else {
                        print "ERROR: Incorrect syntax supplied\n\n";
                        &show_help; exit(1);
                }
        }
        &show_help; exit(0);
}

# Show command usage
sub show_help {
print <<TEXT;
Usage: bindstat <options>

  -c | --capture        Capture and log data (this should be scheduled)
  -g | --graph          Create graphs (Last 24 Hours,weekly,monthly) 
  -h | --help           Show this help
  -i | --initialise     Create empty dataset and default config
  -l | --showlog        List logged data
  -r | --refresh        Refresh capture stats and dont log
  -0 | --reset          Reset stats data
  -s | --stats          Show stats to date

TEXT

}

# Initial Data sets
sub initialise {
#       create working dir, dreate data file, rrd file, config file, need rndc locatiom, rndc stats file loc
        my $i,$fh;
        if ((-d $datalocation ) && (-e $cfgfile)) {
                print "Are you sure, config file already exists (Y/N)? ";
                $i = <STDIN>; 
                if (!($i =~ /^y|^Y/)){
                        print "\nAborted..."; exit(0);
                }
        } 
        mkdir($datalocation,0775) unless (-d $datalocation);
        # create config file
        open $fh, "> $cfgfile" or die "ERROR: Could not create config file $cfgfile...";
        print $fh "logdata=yes\n";
        print $fh "rrdlog=no\n";
        print $fh "warnenabled=yes\n";
        print $fh "warnthreshold=40\n";
        close $fh;
        # create stats file
        open $fh, "> $statsfile" or die "ERROR: Could not create config file $statsfile...";
        print $fh "0\n0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n";
        print $fh "0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n";
        print $fh "0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n";
        close $fh;
        # create log file
        open $fh, "> $logfile" or die "ERROR: Could not create $logfile...";
        print $fh "#date,success,referral,nxrrset,nxdomain,recursion,failure,sample#\n";
        close $fh;
        print "\nConfiguration Completed...\n";
}

# Reset Data sets
sub reset {
#       create working dir, dreate data file, rrd file, config file, need rndc locatiom, rndc stats file loc
        my $i,$fh;
        if (!(-d $datalocation ) && (-e $statsfile)) {
                print "ERROR: No data found - try initialising data or permissions to $statsfile";
				exit(1);
                }
        # create stats file
        open $fh, "> $statsfile" or die "ERROR: Could not create config file $statsfile...";
        print $fh "0\n0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n";
        print $fh "0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n";
        print $fh "0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n0,0,0,0\n";
        close $fh;
        print "Stats Data Reset...\n";
}



# Grab stats and process
sub capture {
        &rndcload; 
        # If Current total is less than last, then something is wrong (reboot, bind restarted,etc)
        if (($total < $lastcount) || ($lastcount eq 0)){
                print "rndc stats out of sync, probably due to bind reset or first capture. Capture\n";
                print "abandoned, will resume next time.\n";
                $lastcount = $total;
                &writestats;
                exit(0);
        }
        ($sec,$min,$hr) = localtime($ntime);
        $samples[$hr]++; 
        $count = $total - $lastcount;
        $avhr[$hr] = int($avhr[$hr] + $count);                  #calc total queries for this hour, calc average later.
        $lastcaphr[$hr] = $count; $lastcaptime[$hr] = $ntime;
        $lastcount = $total;
        &writestats; &write2log if $logdata;
        print "Capture complete...\nTotal queries this capture: $count --> " . int($count/3600) . " qps.\n";
#       print "Total ". $count . " queries in the last " . ($ntime - $lasttime) . " Seconds, ";
#       print "Capture Taken at $hr:$min:$sec...\n";

}

sub refresh {
        &rndcload; 
        # If Current total is less than last, then something is wrong (reboot, bind restarted,etc)
        if (($total < $lastcount) || ($lastcount eq 0)){
                print "rndc stats out of sync, probably due to bind reset or first capture. Capture\n";
                print "abandoned, will resume next time.\n";
                $lastcount = $total;
                &writestats;
                exit(0);
        }
        ($sec,$min,$hr) = localtime($ntime);
        $count = $total - $lastcount;
        $lastcount = $total;
        &writestats;
        print "Capture refresh complete...\nTotal queries this capture: $count --> " . int($count/3600) . " qps.\n";
#       print "Total ". $count . " queries in the last " . ($ntime - $lasttime) . " Seconds, ";
#       print "Capture Taken at $hr:$min:$sec...\n";

}

sub writestats{
        my $fh,$i;
        # Write out stats data.
        open $fh, "> $statsfile" or die "ERROR: Could not create config file $statsfile... $!";
        print $fh "$lastcount\n";
        print $fh "$ntime\n";
        for($i=0; $i < 24; $i++ ){
                #print "$i|" . $avhr[$i] . "|" . $sample[$i] . "|" . $lastcaphr[$i] . "|" . $lastcaptime[$i] . "|\n";
                print $fh "$avhr[$i],$samples[$i],$lastcaphr[$i],$lastcaptime[$i]\n";
        }
        close $fh;

}

sub rndcload{
        my $i = 0, $fh;
   #     unlink $rndcstatsfile if -e $rndcstatsfile;
        system "$rndclocation stats";
        open $fh, "< $rndcstatsfile" or die "ERROR: Could Open file $rndcstatsfile...";
        while(<$fh>){
                next if /Dump/;
                ($junk,$cdata[$i]) = split /\s+/;
                $total += $cdata[$i];
                $i++;
                }
        close $fh;
}

sub write2log{
        my $fh,$i;
        # Write out logged data.
        # date,success,referral,nxrrset,nxdomain,recursion,failure,qcount(q that hr)
        open $fh, ">> $logfile" or die "ERROR: Could not open file $logfile...";
        print $fh "$ntime,";
        for($i=0; $i < 6; $i++ ){
                #print "$i|" . $avhr[$i] . "|" . $sample[$i] . "|" . $lastcaphr[$i] . "|" . $lastcaptime[$i] . "|\n";
                print $fh "$cdata[$i],";
        }
        print $fh "$count\n";
        close $fh;

}


#### DNS Queries per sec, per hour, per day
# hr   av/hr    av/sec  last/hr   last/sec      last captured           Graph
# 00  1400000     300     4000          200             19-09-2008 17:00        ==========
# 01    6000       3      4000          2               19-09-2008 17:00        =
# 02    6000       3      4000          2               19-09-2008 17:00        ==
# 03    6000       3      4000          2               19-09-2008 17:00        ========
# 04    6000       3      4000          2               19-09-2008 17:00        =====

# Av/day        Last/day
# 1455000       1500000
# x number of queries in the past x seconds/mins
