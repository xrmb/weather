#!perl

use LWP::UserAgent;

use mystdredir;
use Whatsup;

use strict;


mystdredir::init(err => 'w.log');

my $ua = new LWP::UserAgent(agent => "yawn");
my $req = new HTTP::Request(GET => "http://hint.fm/wind/wind-data.js");
my $res = $ua->request($req);

if(!$res->is_success())
{
  print(STDERR localtime()."\tcant get data, ".$res->status_line()."\n");
  exit __LINE__;
}

my $d = $res->content();
unless($d =~ /}\s*$/)
{
  print(STDERR localtime()."\tincomplete\n");
  exit __LINE__;
}

my %m = (january => 1, february => 2, march => 3, april => 4, may => 5, june => 6, july => 7, august => 8, september => 9, october => 10, november => 11, december => 12);

unless($d =~ /timestamp: "(\d+):(\d+) (am|pm) on (\w+) (\d+), (\d+)",/)
{
  print(STDERR localtime()."\tno timestamp in file\n");
  exit __LINE__;
}

mkdir(sprintf("w/%04d", $6));
mkdir(sprintf("w/%04d/%02d", $6, $m{lc($4)}));
my $fn = sprintf("w/%04d/%02d/%04d%02d%02d_%02d%02d.dat", $6, $m{lc($4)}, $6, $m{lc($4)}, $5, ($1 % 12) + ($3 eq 'am' ? 0 : 12), $2);
my $fh;
if(!open($fh, '>', $fn))
{
  print(STDERR localtime()."\tcant create $fn ($!)\n");
  exit __LINE__;
}
binmode($fh);
print($fh $d);
close($fh);

unlink("$fn.bz2");
system("bzip2 -9 $fn");

Whatsup->record(app => 'weather_v', wind => 1);

exit 0;
