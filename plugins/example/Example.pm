package Example;

sub example_biblio_transformed {
    my ($biblio, $context) = @_;
    #print $biblio->as_formatted;
}

sub example_is_duplicate {
    my ($biblio, $context) = @_;

    # Don't save this biblio.
    $context->{insert} = 0;
}

1;
