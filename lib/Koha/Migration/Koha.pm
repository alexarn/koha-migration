package Koha::Migration::Koha;

use C4::Biblio;
use C4::Context;

sub new {
    my $class = shift;

    my $this = {
        'id_field' => GetMarcFromKohaField('biblio.biblionumber', ''),
    };

    return bless $this, $class;
}

sub addBiblioItems {
    my ($this, $biblio) = @_;

    my $fmk = '';
    my @ids = ( eval { AddBiblio($biblio, $fmk, { defer_marc_save => 1 }); } )[0,1];
    if ( $@ or not @ids ) {
        say $biblio->as_formatted;
        say $@;
        die "AddBiblio: ".$biblio->leader().", $@";
    }
    else {
        my ($itemnumbers, $errors) = eval { AddItemBatchFromMarc( $biblio, @ids, $fmk ) };
        if ( $@ ) {
            say $biblio->as_formatted;
            die "AddItemBatchFromMarc: ".$biblio->leader().", $@";
        }
        eval { ModBiblioMarc( $biblio, $ids[0], $fmk ) };
        if ( $@ ) {
            say $biblio->as_formatted;
            die "ModBiblioMarc: ".$biblio->leader().", $@";
        }
    }
    return $ids[0];
}

sub getbiblios {
    my $this = shift;

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT biblionumber FROM biblio");
    $sth->execute();
    my $data = $data = $sth->fetchall_arrayref({});
    $sth->finish;

    my $biblios;
    foreach my $entry (@{ $data }) {
        $biblionumber = $entry->{biblionumber};
        $biblio = GetMarcBiblio($biblionumber);

        if ($biblio) {
            push @{ $biblios }, $biblio;
        }
    }
    return $biblios;
}

1;
