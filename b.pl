#!perl
use strict;

use XML::Simple;
use File::Touch;
use LWP::UserAgent;

use mystdredir;
use myargv;

use bfunc;

mystdredir::init(err => 'b.log');

my $VERBOSE=hasargv('v', 'verbose');
my $UA=new LWP::UserAgent(agent => "yawn");
my $REQ=new HTTP::Request(GET => "http://gima.weather.com/TileServer/serieslist.do");
my $RES=$UA->request($REQ);

if(!$RES->is_success())
{
  print(STDERR localtime()."\tcant get series list, ".$RES->status_line()."\n");
  exit __LINE__;
}

my $SL=$RES->content();

my @URL=
qw(
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0212.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0213.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0302.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0303.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0230.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0231.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0320.png
    http://g0.imwx.com/TileServer/imgs/{MAP}/u{TS}/0321.png

    http://g1.imwx.com/TileServer/imgs/{MAP}/u{TS}/0212.png
);

my %IGNORE=(
    eurorad=>1,
    feelslike=>1,
    traffic=>1,
    uv=>1,
    sat=>1,
    aussieradar=> 1,
  );


if(0)
{
  my $fh;
  open($fh, '>', 'serieslist.xml');
  print($fh $SL);
  close($fh);
}


my $XML=XMLin($SL, ForceArray=>1, KeyAttr=>[]);
if(!$XML)
{
  print(STDERR localtime()."\terror parsing series list\n");
  exit __LINE__;
}

if(!-d 'b')
{
  if(!mkdir('b'))
  {
    print(STDERR localtime()."\tcant create dir 'b'.\n");
    exit __LINE__;
  }
}

foreach my $A (keys(%{$XML->{seriesInfo}[0]}))
{
  next if $A =~ /_ff$/;
  if($IGNORE{$A}) { next; }

  foreach my $B (@{$XML->{seriesInfo}[0]{$A}})
  {
    ### dont know what this is ###
    if($B->{native} eq "5")
    {
      next;
    }

    if(!-d 'b/'.$A)
    {
      if(!mkdir('b/'.$A))
      {
        print(STDERR localtime()."\tcant create dir 'b/$A'.\n");
        next;
      }
    }


    foreach my $C (@{$B->{series}})
    {
      my $TS=$C->{unixDate};
      my @TS=localtime($TS/1000);
      my $TSD=sprintf("%04d%02d%02d%02d%02d", $TS[5]+1900, $TS[4]+1, $TS[3], $TS[2], $TS[1]);
      if(-f "b/".$A."/".$TSD.".png")
      {
        next;
      }

      print("b/".$A."/".$TSD."...\n");
      my $FN0="b/".$A."/".$TSD."_{ID}.png";

      my $LFN;
      foreach my $URL0 (@URL)
      {
        my $URL=$URL0;
        $URL=~s/\{MAP\}/$A/;
        $URL=~s/\{TS\}/$TS/;
        my $ID=$URL0;
        $ID=~s/^.*\///;
        $ID=~s/\.png$//;
        my $FN=$FN0;
        $FN=~s/\{ID\}/$ID/;

        if(-f $FN)
        {
          $LFN=$FN;
          next;
        }

        if($VERBOSE) { print("get: $URL\n"); }

        $REQ=new HTTP::Request(GET => $URL);
        $RES=$UA->request($REQ);

        if(!$RES->is_success())
        {
          print(STDERR localtime()."\tcant get image '$URL', ".$RES->status_line()."\n");
          next;
        }

        my $DATA=$RES->content();
        my $FH;
        if(!open($FH, ">".$FN))
        {
          print(STDERR localtime()."\tcant create '$FN'\n");
          next;
        }
        binmode($FH);
        print($FH $DATA);
        close($FH);

        $LFN=$FN;
      }

      if($LFN)
      {
        my($R, $MSG)=stitch($LFN);
        if($R)
        {
          print(STDERR localtime()."\tstitch error $R, $MSG\n");
        }
        else
        {
          my $T=new File::Touch(mtime => $TS, no_create => 1);
          $T->touch($LFN);
        }
      }
    }
  }
}

