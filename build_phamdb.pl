#!/usr/bin/perl -w
use strict;
use warnings;
use File::Fetch;

#IMPORTANT: Needs BLAST loaded in order to run.

MAIN();

sub MAIN{
  GET_PHAMS();
  my @phams = COMBINE_PHAMS();
  my %paired_metadata = GET_METADATA(@phams);
  APPLY_METADATA(\%paired_metadata);
  BLAST_DB();
}

sub GET_PHAMS{
  mkdir("pham_fastas");
  system("wget http://databases.hatfull.org/Actino_Draft/fastas.zip");
  system("unzip fastas.zip -d pham_fastas");
}

sub COMBINE_PHAMS{
  #combine pham files
  my @fastafiles = glob"pham_fastas/fastas/*.fasta";
  my @pham_numbers;
  open(OUT, "+> allphams.faa");
  foreach my $infile (@fastafiles){
    my($pham)=($infile=~/.*\/(.*?)\_.*/);
    push(@pham_numbers,$pham);
    open(IN, "< $infile");
    while(<IN>){
      chomp;
      if($_=~/\>/){
        my($phage,$cluster)=($_=~/\>(.*?)\ .*?\[cluster\=(.*?)\].*/);
        $phage = REMOVE_SPECIAL_CHARACTERS($phage);
        $cluster = REMOVE_SPECIAL_CHARACTERS($cluster);
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
  return(@pham_numbers);
}

sub GET_METADATA{
  #get pham numbers and other data
  my @phams_to_process = @_;
  mkdir("pham_csvs");
  my %products;

  foreach my $pham (@phams_to_process){
    my $url = 'https://phagesdb.org/phams/genelist/'.$pham;
    my $ff = File::Fetch->new(uri => $url);
    my $file = $ff->fetch(to => 'pham_csvs');
    open(IN, "< $file") or die "Error. Check pham $pham OR file $file.\n";
    my $counter=0;
    while(<IN>){
      chomp;
      $counter++;
      next if($counter <= 1);
      my($product)=($_=~/.*\t(.*)/);
      next if(!defined $product);
      if($product eq "b\'\'"){
        $product = "product_unkown";
      }
      $product=~s/b"//g;
      $product=~s/b'//g;
      $product=~s/'//g;
      $product = REMOVE_SPECIAL_CHARACTERS($product);
      $products{$pham}=$product;
      last;
    }
    close IN;
  }
  return(%products);
}

sub APPLY_METADATA{
  my $hash_ref = shift;
  my %metadata = %{$hash_ref};
  my $counter = 0;
  #apply pham numbers to database
  open(OUT, "+> temp.txt");
  open(PHAM, "< allphams.faa");
  while(<PHAM>){
    if($_=~/\>/){
      chomp;
      my($phage,$cluster,$pham)=($_=~/\>(.*?)\ (.*?)\ (.*)/);
      if(!exists $metadata{$pham} || !defined $metadata{$pham}){
        print OUT ">$phage\_UID\_$counter\ $cluster\ $pham\ "." product_unkown\n"
      }
      else{
        print OUT ">$phage\_UID\_$counter\ $cluster\ $pham\ "." $metadata{$pham}\t$counter\n";
      }
      $counter++;
    }
    else{
      print OUT $_;
    }
  }
  close PHAM;
  close OUT;
  unlink "allphams.faa";
  rename "temp.txt", "allphams.faa";
}

sub REMOVE_SPECIAL_CHARACTERS{
  my $input_string = shift;
  $input_string=~s/[\|\ \[\]\(\)\:\;\/\.\-\~\`\!\@\#\$\%\^\&\*\=\+\{\}\?]/\_/g;
  return($input_string);
}

sub BLAST_DB{
  #make blastdatabse
  system("makeblastdb -in allphams.faa -dbtype prot -parse_seqids");
}
