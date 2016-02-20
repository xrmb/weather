#!perl

use strict;
use Cwd;

$|=1;
$ENV{CYGWIN} = 'nodosfilewarning';


my %dbd;
if(open(my $fh, '<', 'optimize.dbn'))
{
  %dbd = map { chomp; $_ } <$fh>;
  close($fh);
}

my %dbt;
foreach my $p (keys(%dbd))
{
  next unless($p =~ /\.png$/);
  next unless(-f $p);
  next unless(-M $p > 3/24);

  my @p = split(/\//, $p);
  my $fn = pop(@p);
  my $dt = substr($fn, 0, 6);
  my $dir = join('/', @p);

  push(@{$dbt{$dt}{$dir}}, [$fn, $dbd{$p}]);
}


open(my $log, '>>', 'zipit.dbn') || die;
my $b = cwd();
foreach my $dt (sort(keys(%dbt)))
{
  foreach my $dir (sort(keys(%{$dbt{$dt}})))
  {
    my @p = split(/\//, $dir);

    my $zipcmd = sprintf('zip -o -D -0 -u -@ -m %s/a/%s/%s.zip', $b, $p[-1], $dt);
    print("$b/$dir $zipcmd\n");

    mkdir($b.'/a');
    mkdir($b.'/a/'.$p[-1]);

    chdir($b.'/'.$dir);

    open(my $zip, '|-', $zipcmd) || die;
    print($zip join("\n", sort map { $_->[0] } @{$dbt{$dt}{$dir}}));
    close($zip);

    foreach my $png (@{$dbt{$dt}{$dir}})
    {
      print($log $p[-1].'/'.$png->[0]."\n");
      print($log $png->[1]."\n");

      if(-f $png)
      {
        print(STDERR "$png is still there\n");
      }
    }

    unlink(sprintf('%s/d/zipmap/%s/%s.zmap', $b, $p[-1], $dt));
  }
}
close($log);
