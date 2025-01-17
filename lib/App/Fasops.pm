package App::Fasops;
use strict;
use warnings;
use autodie;

use 5.008001;

our $VERSION = '0.2.0';

use App::Cmd::Setup -app;
use Carp;
use File::Basename;
use List::MoreUtils;
use IO::Zlib;
use Path::Tiny;
use Tie::IxHash;
use YAML::Syck;

sub decode_header {
    my $header = shift;

    # S288C.chrI(+):27070-29557|species=S288C
    my $head_qr = qr{
                ([\w_]+)?           # name
                [\.]?               # spacer
                ((?:chr)?[\w-]+)    # chr name
                (?:\((.+)\))?       # strand
                [\:]                # spacer
                (\d+)               # chr start
                [\_\-]              # spacer
                (\d+)               # chr end
            }xi;

    tie my %info, "Tie::IxHash";

    $header =~ $head_qr;
    my $name     = $1;
    my $chr_name = $2;

    if ( defined $name ) {
        %info = (
            chr_name   => $2,
            chr_strand => $3,
            chr_start  => $4,
            chr_end    => $5,
        );
        if ( !defined $info{chr_strand} ) {
            $info{chr_strand} = '+';
        }
        elsif ( $info{chr_strand} eq '1' ) {
            $info{chr_strand} = '+';
        }
        elsif ( $info{chr_strand} eq '-1' ) {
            $info{chr_strand} = '-';
        }
    }
    elsif ( defined $chr_name ) {
        $name = $header;
        %info = (
            chr_name   => $2,
            chr_strand => $3,
            chr_start  => $4,
            chr_end    => $5,
        );
        if ( !defined $info{chr_strand} ) {
            $info{chr_strand} = '+';
        }
        elsif ( $info{chr_strand} eq '1' ) {
            $info{chr_strand} = '+';
        }
        elsif ( $info{chr_strand} eq '-1' ) {
            $info{chr_strand} = '-';
        }
    }
    else {
        $name = $header;
        %info = (
            chr_name   => 'chrUn',
            chr_strand => '+',
            chr_start  => undef,
            chr_end    => undef,
        );
    }
    $info{name} = $name;

    # additional keys
    if ( $header =~ /\|(.+)/ ) {
        my @parts = grep {defined} split /;/, $1;
        for my $part (@parts) {
            my ( $key, $value ) = split /=/, $part;
            if ( defined $key and defined $value ) {
                $info{$key} = $value;
            }
        }
    }

    return \%info;
}

sub encode_header {
    my $info = shift;

    my $header;
    $header .= $info->{name};
    $header .= "." . $info->{chr_name};
    $header .= "(" . $info->{chr_strand} . ")";
    $header .= ":" . $info->{chr_start};
    $header .= "-" . $info->{chr_end};

    # additional keys
    my %essential = map { $_ => 1 }
        qw{name chr_name chr_strand chr_start chr_end seq full_seq};
    my @parts;
    for my $key ( sort keys %{$info} ) {
        if ( !$essential{$key} ) {
            push @parts, $key . "=" . $info->{$key};
        }
    }
    if (@parts) {
        my $additional = join ";", @parts;
        $header .= "|" . $additional;
    }

    return $header;
}

sub parse_block {
    my $block = shift;

    my @lines = grep {/\S/} split /\n/, $block;
    croak "headers not equal to seqs\n" if @lines % 2;

    tie my %info_of, "Tie::IxHash";
    while (@lines) {
        my $header = shift @lines;
        $header =~ s/^\>//;
        chomp $header;

        my $seq = shift @lines;
        chomp $seq;

        my $info_ref = App::Fasops::decode_header($header);
        $info_ref->{seq} = $seq;
        $info_of{ $info_ref->{name} } = $info_ref;
    }

    return \%info_of;
}

sub read_sizes {
    my $file       = shift;
    my $remove_chr = shift;

    my @lines = path($file)->lines( { chomp => 1 } );
    my %length_of;
    for (@lines) {
        my ( $key, $value ) = split /\t/;
        $key =~ s/chr0?// if $remove_chr;
        $length_of{$key} = $value;
    }

    return \%length_of;
}

sub read_names {
    my $file = shift;

    my @lines = path($file)->lines( { chomp => 1 } );

    return \@lines;
}

1;

__END__

=head1 NAME

App::Fasops - operating blocked fasta files

=head1 SYNOPSIS

    commands: list the application's commands
        help: display a command's help screen
  
     axt2fas: convert axt to blocked fasta
     maf2fas: convert maf to blocked fasta
       names: scan a blocked fasta file and output all names
       split: split a blocked fasta file to seperate per-alignment files
      subset: extract a subset of names from a blocked fasta

See C<fasops commands> for usage information.

=cut
