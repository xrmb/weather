#!perl

use strict;
use Term::ReadKey;

use threads;
use Thread::Queue;
use threads::shared;
use Win32::Process;
use Win32::Console::ANSI;
use Term::ANSIColor;
use Time::Local;
use Thread::Semaphore;
use Time::HiRes;

use myscant;

#sub color { return ''; }

my $color_green = color('green');
my $color_yellow = color('yellow');
my $color_reset = color('reset');

my $out = '';
share($out);

#$|=1;

my $db :shared = shared_clone({});
#$db->{aa} = 2;
#my @thr = map {
#  threads->create(sub
#  {
#    for(1..10)
#    {
#      $db->{threads->tid().'_'.$_} = 1;
#      warn join(" ", keys %$db);
#      sleep(1);
#    }
#  }, { db => $db })} 1..10;
#
#for(1..15)
#{
#  #warn join(" ", keys %$db);
#  sleep(1);
#}
#exit;

my $thread_limit = $ARGV[0] || $ENV{NUMBER_OF_PROCESSORS} || 2;
my $q = Thread::Queue->new();
my $sdb = Thread::Semaphore->new();

if(-f 'optimize.dbn' && !-s 'optimize.dbn') { die 'db broken?'; }
if(open(my $fh, '<', 'optimize.dbn'))
{
  print("loading db... ");
  my %db = map { chomp; $_ } <$fh>;
  close($fh);
  foreach my $k (sort keys(%db))
  {
    next if($k =~ /\.png$/ && !-f $k);
    #next if($k !~ /\.png$/);  ### erase all stats
    #next if($k !~ /\.png$/ && $k !~ /^optipng_opt_/);  ### erase some stats
    $db->{$k} = $db{$k};
  }
  print("done\n\n");
}


if (Win32::Process::Open(my $currentProcess, Win32::Process::GetCurrentProcessID(), 0))
{
  $currentProcess->SetPriorityClass(Win32::Process::IDLE_PRIORITY_CLASS());
}


### build cmdline for optipng ###
my %oo;
share(%oo);
sub oo
{
  $sdb->down();

  unless($db->{count})
  {
    $sdb->up();
    return;
  }

  my $out;
  my %s;
  foreach my $k (sort grep { /^optipng_opt_/ } keys(%$db))
  {
    my @s = split(/_/, $k);
    $s{$s[2]}{$s[3]} = $db->{$k};
  }

  foreach my $k (sort keys(%s))
  {
    next if($k eq 'all');

    my %o;
    my $l = 5;
    my $c = 0;
    foreach my $o (sort { $s{$k}{$b} <=> $s{$k}{$a} } keys(%{$s{$k}}))
    {
      my @o = split(/ /, $o);
      while(@o)
      {
        $o{shift(@o)}{shift(@o)} = 1;
      }
      $out .= sprintf("%-10s %s\t%d\n", $k, $o, $s{$k}{$o});
      $c += $s{$k}{$o};
      last unless(--$l);
    }

    $oo{$k} = join(' ', map { $_.join(',', sort keys(%{$o{$_}}))} keys(%o));
    $out .= sprintf("%-10s %s\t%d\n", $k, $oo{$k}, $c);

    if($c < 500) { delete($oo{$k}); }
    $out .= sprintf("\n");
  }


  my @m = sort map { /^count_([a-z]+)$/; $1 } grep { /^count_([a-z]+)$/ } keys(%$db);
  $out .= sprintf("\n");
  $out .= sprintf("%-10s %d\n", 'count', $db->{count});

  $out .= sprintf("\n");
  $out .= sprintf("%-10s %-10s %10s %10s\n", 'stat', 'map', 'optipng', 'pngout');

  my $bb = sub
  {
    my ($t, $m, $o, $p) = @_;

    $out .= sprintf("%-10s %-10s %s%10s %s%10s%s  %5.1f%% %s %5.1f%%\n", $t, $m,
        $o < $p ? $color_green : $color_reset, abs($o),
        $o > $p ? $color_green : $color_reset, abs($p),
        $color_reset,
        abs(100*$o/($o+$p)),
        ('.' x int(40*$o/($o+$p))).($o && $p ? '|' : '').('.' x int(40*$p/($o+$p))),
        abs(100*$p/($o+$p)),
      );
  };

  $bb->('bytes', 'all', $db->{optipng_size}, $db->{pngout_size});
  foreach my $m (@m)
  {
    next if($m eq 'all');
    $bb->('', $m, $db->{'optipng_size_'.$m}, $db->{'pngout_size_'.$m});
  }
  $out .= sprintf("\n");

  $bb->('win', 'all', -$db->{optipng_wincount}, -$db->{pngout_wincount});
  foreach my $m (@m)
  {
    next if($m eq 'all');
    $bb->('', $m, -$db->{'optipng_wincount_'.$m}, -$db->{'pngout_wincount_'.$m});
  }
  $out .= sprintf("\n");

  $bb->('time', 'all', int($db->{optipng_time}), int($db->{pngout_time}));
  foreach my $m (@m)
  {
    next if($m eq 'all');
    $bb->('', $m, int($db->{'optipng_time_'.$m}), int($db->{'pngout_time_'.$m}));
  }
  $out .= sprintf("\n");

  $sdb->up();

  return $out;
}


my $exit = 0;
share($exit);

sub process
{
  my ($p) = @_;

  my $m = (split(/\//, $p))[-2];

  return unless $p =~ m!/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\.png!;
  my $ts = timelocal reverse($1 - 1900, $2 - 1, $3, $4, $5, 0);

  my $ss = -s $p;
  my $sb = 512*1024 + 3078; ### not sure where the 3078 comes from


  my $fh;
  my $png;
  open($fh, '<', $p) || return;
  read($fh, $png, $ss);
  close($fh);

  if($png !~ /^\x89PNG/ || $png !~ /\x42\x60\x82$/)
  {
    print(STDERR "broken png? $p\n");
    return;
  }


  my $so;
  my %of;
  my $sp;

  my $oo = '-zc9 -zm6-9 -zs3 -f0,4,5' || '-o7 -zm1-9';

  my $op;
  my $po;

  my $tos;
  my $toe;
  my $tps;
  my $tpe;

  $sdb->down();
  my $count = $db->{'count_'.$m};
  my $ratio = $db->{'optipng_wincount_'.$m} / (($db->{'optipng_wincount_'.$m} + $db->{'pngout_wincount_'.$m}) || 1);
  $sdb->up();

  my $full = '';
  if(1 || rand() < .1 || $count < 1000)
  {
    $full = '*';

    $tos = Time::HiRes::time();
    $op = `optipng -v $oo -strip all -full $p`;
    $toe = Time::HiRes::time();

    $tps = Time::HiRes::time();
    $po = `pngout /k /v $p`;
    $tpe = Time::HiRes::time();
  }
  else
  {
    if($ratio >= 0.02)
    {
      $oo = $oo{$m} || $oo;

      $tos = Time::HiRes::time();
      $op = `optipng -v $oo -strip all -full $p`;
      $toe = Time::HiRes::time();
    }
    else
    {
      $so = -1;
    }

    if($ratio <= 0.98)
    {
      $tps = Time::HiRes::time();
      $po = `pngout /k /v $p`;
      $tpe = Time::HiRes::time();
    }
    else
    {
      $sp = -1;
    }
  }


  if($op)
  {
    $op =~ s/[ \t]+/ /g;
    while($op =~ s/zc = (\d+) zm = (\d+) zs = (\d+) f = (\d+) IDAT size = (\d+)//)
    {
      push(@{$of{$5}}, "-zc $1 -zm $2 -zs $3 -f $4");
    }
    if(!%of)
    {
      print("optipng out error:\n$op\n");
      return;
    }
    ($so) = sort { $a <=> $b } keys(%of);
  }


  if($po)
  {
    $po =~ s/[ \t]+/ /g;
    while($po =~ s/Out:\s*(\d+)\s+bytes//)
    {
      $sp = $1 - 8; ### 8 = png signature
    }
    if(!$sp)
    {
      print("pngout out error\n$po");
      return;
    }

    while($po =~ s/Required chunk: (....) ........ (........) ........//)
    {
      $sp -= 4; ### length
      $sp -= 4; ### tag
      $sp -= 4; ### crc32
      if($1 ne 'IDAT')
      {
        $sp -= hex($2);
      }
    }
  }


  #lock($db);
  $sdb->down();

  $db->{'count'}++;
  $db->{'count_'.$m}++;

  if($op && %of)# && $so <= $sp)
  {
    foreach my $of (@{$of{$so}})
    {
      $db->{'optipng_opt_all_'.$of}++;
      $db->{'optipng_opt_'.$m.'_'.$of}++;
    }
  }

  $db->{$p} = "$so $sp";
  if($op && $po)# && $so > 1000 && $sp > 1000)
  {
    $db->{'optipng_size'} += $so;
    $db->{'optipng_size_'.$m} += $so;
    $db->{'optipng_count'}++;
    $db->{'optipng_count_'.$m}++;
    $db->{'optipng_time'} += $toe-$tos;
    $db->{'optipng_time_'.$m} += $toe-$tos;

    $db->{'pngout_size'} += $sp;
    $db->{'pngout_size_'.$m} += $sp;
    $db->{'pngout_count'}++;
    $db->{'pngout_count_'.$m}++;
    $db->{'pngout_time'} += $tpe-$tps;
    $db->{'pngout_time_'.$m} += $tpe-$tps;

    if($so <= $sp)
    {
      $db->{'size'} += $so;
      $db->{'size_'.$m} += $so;
      $db->{'optipng_winsize'} += $sp;
      $db->{'optipng_winsize_'.$m} += $sp;
      $db->{'optipng_wincount'}++;
      $db->{'optipng_wincount_'.$m}++;
    }
    else
    {
      $db->{'size'} += $sp;
      $db->{'size_'.$m} += $sp;
      $db->{'pngout_winsize'} += $sp;
      $db->{'pngout_winsize_'.$m} += $sp;
      $db->{'pngout_wincount'}++;
      $db->{'pngout_wincount_'.$m}++;
    }
  }
  else
  {
    $db->{'size'} += $op ? $so : $sp;
    $db->{'size_'.$m} += $op ? $so : $sp;
  }

  utime($ts, $ts, $p);

  my $sn = -s $p;
  my $o = sprintf(
      "%-40s %8d %s%8d%s %s%8s%s %s%8s%s %s%8s%s %s%8s%s %8s %8s %7.3f%% %7.3f%%\n",
      $p.$full,
      $ss,
      $sn < $ss ? $color_yellow : $color_reset, $sn, $color_reset,
      $so < $sp && $so > 0 ? $color_green : $color_reset, $so > 0 ? $so : '-', $color_reset,
      $sp < $so && $sp > 0 ? $color_green : $color_reset, $sp > 0 ? $sp : '-', $color_reset,
      $toe-$tos < $tpe-$tps && $so > 0 ? $color_green : $color_reset, $so > 0 ? sprintf('%7.3fs', $toe-$tos) : '-', $color_reset,
      $tpe-$tps < $toe-$tos && $sp > 0 ? $color_green : $color_reset, $sp > 0 ? sprintf('%7.3fs', $tpe-$tps) : '-', $color_reset,
      $so > 0 ? sprintf('%7.3f%%', 100*$so/$sb) : '-',
      $sp > 0 ? sprintf('%7.3f%%', 100*$sp/$sb) : '-',
      100*$db->{'optipng_size_'.$m}/($sb*$db->{'optipng_count_'.$m} || 1),
      100*$db->{'pngout_size_'.$m}/($sb*$db->{'pngout_count_'.$m} || 1)
    );

  $out .= $o;
  $sdb->up();
}


sub savedb
{
  unlink($ENV{TEMP}.'/optimize.dbn');
  rename('optimize.dbn', $ENV{TEMP}.'/optimize.dbn');
  if(open(my $fh, '>', 'optimize.dbn'))
  {
    $sdb->down();

    binmode($fh);
    print($fh join("\n", %$db));
    close($fh);

    $sdb->up();
  }
}



# Worker threads
my @thr = map {
  threads->create(sub
  {
    while(defined(my $item = $q->dequeue()))
    {
      last if($exit);

      process($item);
    }
    print(localtime."\tthread done (exit $exit)\n");
  })#->detach();
} 1..$thread_limit;


push(@thr,
  scant(
    path => 'b',
    filter => qr/\d\d\d\d\d\.png$/,
    #sample => 7,
    final => sub
    {
      $q->end();
      print(localtime."\tscanning done (exit $exit)\n");
    },
    code => sub
    {
      my ($p, %args) = @_;

      if($db->{$p}) { return; }

      $q->enqueue($p);
      while($q->pending() > 10) { sleep(1); }

      return $exit;
    },
  ));#->detach());


my $c = 0;
while(grep { $_->is_running() } threads->list())
{
  #print($out); $out = '';

  my $key = lc(ReadKey(2) || '');
  if($key eq 'x')
  {
    print("x-key\n");
    $exit = 1;
    while(grep { $_->is_running() } threads->list()) { sleep(1); }
  }

  if($key eq 'i')
  {
    print oo();
  }

  if($c % 100 == 0 && !$exit)
  {
    oo();

    my $o = sprintf(
        "%-40s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s\n",
        'file',
        'sz-in',
        'sz-out',
        'optipng',
        'pngout',
        'opti-tm',
        'pngo-tm',
        'optipng%',
        'pngout%',
        'type',
      );
  }

  $c++;

  if($c % 100 == 0) { savedb(); }
}
$_->join() for threads->list(threads::joinable);

savedb();
