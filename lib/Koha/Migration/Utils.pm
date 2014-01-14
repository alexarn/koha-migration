package Koha::Migration::Utils;

sub cleanIsbn {
    my ($class, $isbn) = @_;

    $isbn =~ s/-//gi;
    return $isbn;
}

sub remove_special_chars {
    my ($class, $string) = @_;

    $string =~ s/\W//g;
    return $string;
}

1;
