#!perl

use strict;
use myscant;
use File::Basename;
use File::Path qw(make_path);

scan(path => 'a', filter => qr/\.zip$/, code => sub
{
  my ($fnz) = @_;

  my $fnm = $fnz;
  substr($fnm, -3, 3, 'zmap');
  substr($fnm, 0, 1, 'd/zmap');

  if(-f $fnm) { return; }

  my $dnm = dirname($fnm);
  if(!-d $dnm) { make_path($dnm); }


  open(my $fhm, '>', $fnm) || return;
  open(my $fhz, '<', $fnz) || return;
  binmode($fhz);
  while(!eof($fhz))
  {
    my $data;
    read($fhz, $data, 4);

    my ($pk, $sig1, $sig2) = unpack('A2CC', $data);
    if($pk ne 'PK') { die; }

    if($sig1 == 3 && $sig2 == 4)
    {
      read($fhz, $data, 26);

      my ($version, $flags, $comp, $modtime, $moddate, $crc, $sizec, $size, $fnl, $efl) = unpack('SSSSSLLLSS', $data);

      my $fn;
      read($fhz, $fn, $fnl);

      my $ef;
      read($fhz, $ef, $efl);

      die if($size != $sizec);

      printf($fhm "%s\t%d\t%d\n", substr($fn, 0, -4), tell($fhz), $sizec);

      read($fhz, $data, $sizec);
    }

    elsif($sig1 == 1 && $sig2 == 2)
    {
      read($fhz, $data, 42);

      my ($version, $version2, $flags, $comp, $modtime, $moddate, $crc, $sizec, $size, $fnl, $efl, $fcl) = unpack('SSSSSSLLLSSSSSLL', $data);

      my $fn;
      read($fhz, $fn, $fnl);

      my $ef;
      read($fhz, $ef, $efl);

      my $fc;
      read($fhz, $fc, $fcl);
    }

    elsif($sig1 == 5 && $sig2 == 6)
    {
      read($fhz, $data, 18);

      my ($disk, $diskwcd, $diskent, $totent, $cds, $off, $cl) = unpack('SSSSSSLLLSSSSSLL', $data);

      my $c;
      read($fhz, $c, $cl);
    }

    else
    {
      die "$pk $sig1 $sig2";
    }
  }
  close($fhz);
  close($fhm);

  return;
});
