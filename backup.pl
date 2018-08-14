#!/usr/bin/perl

############################################
## Backup /var/www /etc and all databases ##
##       to FTP server                    ##
############################################
## Author: 007hacky007                    ##
############################################
## Description:                           ##
## 1. create mysql backup and save it to  ##
##    /var/backup                         ##
## 2. gzip /var/www, /etc, /var/vmail     ##
## 3. save everything with date suffix    ##
## 4. copy all above to FTP               ##
## 5. delete date-X from FTP              ##
## 6. delete /var/backup/...              ##
############################################

#####
# Needed variables

#Backup MySQL
$backupMySQL = 1;

#Backup /var/www
$backupWWW = 1;

#Backup /etc
$backupEtc = 1;

#Backup /var/vmail
$backupVmail = 1;

#MySQL root password
$mysqlPass = "";

# FTP server
$ftpServer = "";

# FTP username
$ftpUsername = "";

# FTP password
$ftpPassword = "";

# FTP folder
$ftpFolder = "backups";

# backup depth how much days to keep
$depth = 3;

#enable log rotate
$logrotate = 1;

#compress method gzip/bzip2
$compressMethod = "gzip";

### END OF CONFIGURATION ###

########################################################
## CORE OF HELL, dont touch anything below this line: ##
########################################################

#tar -cvjf /var/backup/etc.tar.bz2 /etc > /var/backup/etc.list
#tar -cvjf /var/backup/www.tar.bz2 /var/www > /var/backup/www.list
#tar -cvjf /var/backup/vmail.tar.bz2 /var/vmail > /var/backup/vmail.list
#mysqldump --all-databases -u root -p password | bzip2 -c > /var/backup/mysql.sql.bz2

#open LOG file & append STDOUT, STDERR
if($logrotate == 1){
	unless(-e "/etc/logrotate.d/backuppl"){
		open(LOGROTATE, ">/etc/logrotate.d/backuppl");
		print LOGROTATE <<END;
/var/log/backuppl.log {
        monthly
        missingok
        rotate 4
        compress
        delaycompress
        notifempty
}
END
		close(LOGROTATE);
	}
}

open(LOG, ">>/var/log/backuppl.log");
open(STDOUT, ">&LOG");
open(STDERR, ">&LOG");

#disable buffers on STDOUT, STDERR and on LOG
my $fh_stdout = select(STDOUT);
$I = 1;
my $fh_stderr = select(STDERR);
$I = 1;
my $fh_log = select(LOG);
select($fh_log); #select LOG as default output

print localtime()." Backup script started ...\n";

use Net::FTP;
use Net::FTP::Throttle;
sub ftpConnect{
	$ftp = Net::FTP::Throttle->new($ftpServer, MegabitsPerSecond => 20, Debug => 0)
		or die localtime()." [!] Cannot connect to $ftpServer: $@\n";
	$ftp->login($ftpUsername,$ftpPassword)
		or die localtime()." [!] Cannot login to FTP: ", $ftp->message."\n";
	$ftp->cwd($ftpFolder)
		or die localtime()." [!] Cannot change directory: ", $ftp->message."\n";
	$ftp->binary();
	print localtime()." Successfully connected to FTP: $ftpServer\n";
}
ftpConnect();
$ftp->quit;

sub result{
	if($mfail == 1){
                print "[FAILED]\n";
        }else{
                print "[OK]\n";
        }
}

sub result2{
        if($temp2 == ""){
                print "[OK]\n";
        }else{
                print "[FAILED]\n";
        }
}
#get current date
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$mon++;
$year = $year + 1900;

$forDelete = 86400*$depth; # in seconds
$forDelete2 = time()-$forDelete;
($sec2,$min2,$hour2,$mday2,$mon2,$year2,$wday2,$yday2,$isdst2) = localtime($forDelete2);
$mon2++;
$year2 = $year2 + 1900;
print "Current date: ".$mday."-".$mon."-".$year."\n";
print "Set for delete: ".$mday2."-".$mon2."-".$year2."\n";
if($backupMySQL == 1){
	print localtime()." Starting MySQL backup ... ";
	$temp2 = `mysqldump --all-databases -u root -p$mysqlPass | $compressMethod -c > /var/backup/mysql_$mday-$mon-$year.sql.gz`;
	result2();
	ftpConnect();
	print localtime()." Copying MySQL backup to FTP ... ";
	$mfail = 0;
	$ftp->put("/var/backup/mysql_$mday-$mon-$year.sql.gz")
		or $mfail = 1;
	result();
	print localtime()." Deleting temporary file ... ";
	$temp2 = `rm -rf /var/backup/mysql_$mday-$mon-$year.sql.gz`;
	result2();
	#delete old backups on FTP
	$mfail = 0;
	print localtime()." Deleting old backup from FTP ... ";
	$ftp->delete("mysql_$mday2-$mon2-$year2.sql.gz")
		or $mfail = 1;
	result();
	$ftp->quit();
}

sub backupFolder{
        print localtime()." Starting $_[0] backup ... ";
	my(@temp) = split(/\//, $_[0]);
	#if($compressMethod == "bzip2"){
	#        $temp2 = `tar -cvjf /var/backup/$temp[-1]_$mday-$mon-$year.tar.bz2 $_[0] > /var/backup/$temp[-1]_$mday-$mon-$year.list`;
	#}else{
		$temp2 = `tar -cvzf /var/backup/$temp[-1]_$mday-$mon-$year.tar.gz $_[0] > /var/backup/$temp[-1]_$mday-$mon-$year.list`;
	#}
	result2();
	ftpConnect();
        print localtime()." Copying $_[0] backup to FTP ... ";
        $mfail = 0;
        $ftp->put("/var/backup/$temp[-1]_$mday-$mon-$year.tar.gz")
                or $mfail = 1;
        $ftp->put("/var/backup/$temp[-1]_$mday-$mon-$year.list")
                or $mfail = 1;
	result();
        print localtime()." Deleting temporary file ... ";
        $temp2 = `rm -rf /var/backup/$temp[-1]_$mday-$mon-$year.tar.gz`;
        $temp2 = `rm -rf /var/backup/$temp[-1]_$mday-$mon-$year.list`;
	result2();
        # delete old backups on FTP
        $mfail = 0;
	print localtime()." Deleting old backup from FTP ... ";
        $ftp->delete("$temp[-1]_$mday2-$mon2-$year2.tar.gz")
                or $mfail = 1;
        $ftp->delete("$temp[-1]_$mday2-$mon2-$year2.list")
                or $mfail = 1;
        result();
        $ftp->quit();
}

backupFolder("/var/www") if($backupWWW == 1);
backupFolder("/etc") if ($backupEtc == 1);
backupFolder("/var/vmail") if($backupVmail == 1);
close(LOG);
