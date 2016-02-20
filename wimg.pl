#!perl

use strict;
use JSON;
use Image::Magick;
use Statistics::Descriptive;
use Math::Trig;
use List::Util qw(min);

use myscant;

$| = 1;

sub angle
{
  my ($x1, $y1) = @_;
  return 0 if($y1 == 0 && $x1 == 0);

  my $d = rad2deg asin( (abs($x1)) / (sqrt($x1*$x1+$y1*$y1)));

  if($x1 < 0 && $y1 >= 0) { return 90 + $d; }
  if($x1 < 0 && $y1 < 0) { return 270 - $d; }
  if($x1 > 0 && $y1 < 0) { return 270 + $d; }
  return 90 - $d;
}

#for(0..36) { printf("%d\t%f\t%f\t%d\n", $_*10, cos(deg2rad($_*10)), sin(deg2rad($_*10)), angle(cos(deg2rad($_*10)), sin(deg2rad($_*10)))); }

sub wimg
{
  my ($fn) = @_;

  print("loading... $fn\n");
  my $fh;
  open($fh, '<', $fn) || die;
  my $c = join('', <$fh>);
  close($fh);

  $c =~ s/var windData = //;


  print("parsing...\n");
  my $json = new JSON();
  $json->relaxed(1);
  $json->allow_barekey(1);

  $c = $json->decode($c);


  #open($fh, '>', $fn.'.dat') || die;
  #foreach my $f (qw(timestamp x0 y0 x1 y1 gridWidth gridHeight))
  #{
  #  print($fh $c->{$f}."\n");
  #}
  #print($fh join(' ', map { int($_*100) } @{$c->{field}})."\n");
  #close($fh);

  my $f = 1;

  print("drawing...\n");
  my $img = new Image::Magick();
  $img->Set(size => sprintf('%dx%d', $c->{gridWidth} * $f, $c->{gridHeight} * $f));
  $img->Read('xc:white');

  my $i = 0;
  #my $sx = new Statistics::Descriptive::Full();
  #my $sy = new Statistics::Descriptive::Full();
  for(my $x = 0; $x < $c->{gridWidth}; $x++)
  {
    for(my $y = $c->{gridHeight}-1; $y >= 0; $y--, $i+=2)
    {
      my $vx = $c->{field}[$i];
      my $vy = $c->{field}[$i+1];

      #$sx->add_data($vx);
      #$sy->add_data($vy);

      next unless($vx && $vy);
      #$img->Draw(primitive => 'line', points => sprintf('%.2f,%.2f %.2f,%.2f', $x*5+2, $y*5+2, $x*5+2+$vx/5, $y*5+2-$vy/5), stroke => '#f00', strokewidth => 1);
      #$img->Draw(primitive => 'rectangle', points => sprintf('%.2f,%.2f %.2f,%.2f', $x*$f, $y*$f, $x*$f+$f-1, $y*$f+$f-1), fill => sprintf("hsb(%f%%, %f%%, %f%%)", angle($vx, $vy)/3.6, 100, min(100, 60+sqrt($vx*$vx+$vy*$vy))));
      $img->Draw(primitive => 'point', points => sprintf('%.2f,%.2f', $x*$f, $y*$f), fill => sprintf("hsb(%f%%, %f%%, %f%%)", angle($vx, $vy)/3.6, 100, min(100, 60+sqrt($vx*$vx+$vy*$vy))));
      #$img->SetPixel(x => $x, y => $y, color => sprintf("hsb(%f%%, %f%%, %f%%)", angle($vx, $vy)/3.6, 100, min(100, 60+sqrt($vx*$vx+$vy*$vy))));
    }
  }

  #printf("stats:\nx-min:\t%f\nx-max:\t%f\ny-min:\t%f\ny-max:\t%f\n", $sx->min(), $sx->max(), $sy->min(), $sy->max());

  print("saving...\n");
  my @out = split(/\//, $fn);
  splice(@out, 1, 0, 'png');
  substr($out[-1], -3, 3, 'png');
  $img->Write(filename => join('/', @out), depth => 8, quality => 90);

  return;
}

scan(path => 'w', filter => qr/\.dat$/, file => \&wimg);
