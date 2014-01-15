package Koha::Migration::Koha;

use C4::Biblio;
use C4::Items;
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
        warn $biblio->as_formatted;
        warn $@;
    }
    else {
        my ($itemnumbers, $errors) = eval { AddItemBatchFromMarc( $biblio, @ids, $fmk ) };
        if ( $@ ) {
            warn $biblio->as_formatted;
            warn $@;
        }
        eval { ModBiblioMarc( $biblio, $ids[0], $fmk ) };
        if ( $@ ) {
            warn $biblio->as_formatted;
            warn $@;
        }
    }
    return $ids[0];
}

sub getBiblioIds {
    my $this = shift;

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT biblionumber FROM biblio");
    $sth->execute();
    my $data = $data = $sth->fetchall_arrayref([]);
    $sth->finish;

    return $data;

}

sub getBiblioData {
    my ($this, $biblionumber) = @_;

    my $biblio = GetMarcBiblio($biblionumber);
    return $biblio;
}

1;
