package bfunc;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(stitch);
our @EXPORT_OK = @EXPORT;

use strict;
use warnings;

use Image::Magick;

#use myimg;


sub stitch
{
  my ($F, $mok)=@_;

  my $FO=$F;
  substr($FO, -9, 5, "");
  if(-f $FO) { return(1, "target exists"); }

  my $I=new Image::Magick();
  $I->Set(size=>'1024x512');
  $I->ReadImage('NULL:black');
  my $X=-1;
  my $Y=0;
  my @DEL;
  foreach my $ID (qw(0212 0213 0302 0303 0230 0231 0320 0321))
  {
    $X++;
    if($X == 4) { $X=0; $Y++; }

    my $FI=$F;
    substr($FI, -8, 4, $ID);
    if(!-f $FI)
    {
      if($mok) { warn("missing '$FI'"); next; }
      return (2, "missing '$FI'");
    }

    my $I0=new Image::Magick();
    if(my $err = $I0->Read(filename=>"$FI"))
    {
      if($mok) { warn("cant read '$FI' ($err)"); next; }
      unlink($FI);
      return(3, "cant read '$FI' ($err)");
    }

    my $XP=$X*256;
    my $YP=$Y*256;
    if(my $R=$I->Composite(image=>$I0, compose=>'over', x=>$XP, y=>$YP))
    {
      return(4, "error '$R' for '$ID' in '$FI'");
    }

    push(@DEL, $FI);
  }

  #$I->Crop(x=>115, y=>119, width=>659, height=>361);
  #$I->Draw(stroke=>'red', primitive=>'rectangle', points=>'115,119 774,480');

  if($I->Write(filename=>$FO, depth=>8, quality=>90))
  {
    return(5, "cant write '$FO'");
  }

  unlink(@DEL);

  if($FO !~ m|/snow/|)
  {
    my @p = $I->GetPixels(width => 1024, height => 512);
    if(!grep { $_ } @p)
    {
      unlink($FO);
      return(6, "$FO is empty");
    }
  }

  #print("raw:\t".(-s $FO)."\n");
  #if(my $R=optipng($FO))
  #{
  #  return(6, "optipng error #$R");
  #}
  #print("optipng:\t".(-s $FO)."\n");
  #if(my $R=pngout($FO))
  #{
  #  return(7, "pngout error #$R");
  #}
  #print("pngout:\t".(-s $FO)."\n");

  return(0, "ok");
}


1;
