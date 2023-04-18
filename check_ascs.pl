#!/usr/bin/perl -w
use strict;
use warnings;

open(IN, "< $ARGV[0]");
open(OUT, "+> asc_list.txt");
while(<IN>){
  if($_=~/\>/){
    print OUT $_;
  }
  else{
    next;
  }
}
close IN;
close OUT;
