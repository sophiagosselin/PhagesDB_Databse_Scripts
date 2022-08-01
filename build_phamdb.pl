#!/usr/bin/perl -w
use strict;
use warnings;

#get pham files
mkdir("pham_fastas");
system("wget http://databases.hatfull.org/Actino_Draft/fastas.zip");
system("unzip fastas.zip -d pham_fastas");

#combine pham files
my @fastafiles = glob"pham_fastas/*.fasta";
open(OUT, "+> allphams.faa");
foreach my $infile (@fastafiles){
  my($pham)=($infile=~/(.*?)\_.*/);
  open(IN, "< $infile");
  while(<IN>){
    chomp;
    if($_=~/\>/){
      my($phage,$cluster)=($_=~/\>(.*?)\ .*?\[cluster\=(.*?)\].*/);
      print OUT ">$phage $cluster $pham\n";
    }
    else{
      $_=~s/\ /\_/g;
      $_=~s/\-//g;
      print OUT "$_\n";
    }
  }
  close IN
}
close OUT;

#get pham numbers and other data
mkdir("pham_csvs");
my @pham_numbers =(1..40000);
my %products;

foreach my $pham (@pham_numbers){
  my $url = 'https://phagesdb.org/phams/genelist/'.$pham;
  print "$url\n";
  my $ff = File::Fetch->new(uri => $url);
  my $file = $ff->fetch(to => 'pham_csvs');
  open(IN, "< pham_csvs/$pham");
  my $counter=0;
  while(<IN>){
    $counter++;
    next if($counter <= 1);
    my($product)=($_=~/.*\t(.*?)\n/);
    next if(!defined $product);
    $product=~s/b"//g;
    $product=~s/b'//g;
    $product=~s/'//g;
    $products{$pham}=$product;
    last;
  }
  close IN;
}

#apply pham numbers to database
open(OUT, "+> temp.txt");
open(PHAM, "< allphams.faa");
while(<PHAM>){
  if($_=~/\>/){
    my($pham)=($_=~/.*\ (.*?)\n/);
    chomp;
    print OUT "$_"." $products{$pham}\n";
  }
  else{
    print OUT $_;
  }
}
close PHAM;
close OUT;

unlink "allphams.faa";
rename "temp.txt", "allphams.faa";

#make blastdatabse
system("makeblastdb -in allphams.faa -dbtype prot -parse_seqids");
