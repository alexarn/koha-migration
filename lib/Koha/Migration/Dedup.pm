package Koha::Migration::Dedup;

use strict;
use warnings;
use Koha::Migration::Marc;
use Koha::Migration::Utils;

sub new {
    my ($class, $config) = @_;

    # We need koha object to know some parameters.
    my $koha = Koha::Migration::Koha->new();

    my $this = {
        'config' => $config,
        'id_field' => $koha->{id_field},
        'dedup' => 0,
        'target' => '',
        'keys' => [],
        'data' => {},
        'valid_targets' => {
            'koha' => 1,
            'files' => 1,
            'both' => 1,
        },
    };


    return bless $this, $class;
}

sub init {
    my $this = shift;

    # Checks if dedup is enable and config is ok.
    $this->check_config;

    # If dedup target is koha or both, we need
    # to load all biblios from koha.
    if ($this->{target} =~ /^(koha|both|)$/) {
        print "Initialize dedup. Checking koha biblios\n" if $main::verbose;
        use Koha::Migration::Koha;
        my $koha = Koha::Migration::Koha->new();
        my $biblios = $koha->getbiblios();
        my $count = 0;
        foreach my $biblio (@{ $biblios }) {
            $count++;
            print "$count\r" if $main::verbose;
            my $id = Koha::Migration::Marc->get($biblio, $this->{id_field});
            $this->add($biblio, $id);
        }
    }
}

sub add {
    my ($this, $biblio, $id) = @_;

    my $config = $this->{config};
    foreach my $key (@{ $config->{keys} }) {
        my $string = $this->buildKey($biblio, $key);
        $key->{name} ||= 'NONE';
        $this->{data}{$key->{name}}{$string} = $id;
    }
}

sub buildKey {
    my ($this, $biblio, $key) = @_;
    my $string;

    my $fields = $key->{key};
    foreach my $field (@$fields) {
        my $value = Koha::Migration::Marc->get($biblio, $field);
        if ($key->{transform}) {
            my $sub = $key->{transform};
            $value = Koha::Migration::Utils->$sub($value);
        }
        $string .= $value;
    }
    return $string;

}

sub match {
    my ($this, $biblio) = @_;
    my $keys = $this->{config}{keys};

    # Sort keys config for respect weight.
    foreach my $key (sort { $a->{weight} <=> $b->{weight} } @{ $keys }) {
        my $string = $this->buildKey($biblio, $key);
        if ($this->{data}{$key->{name}}{$string}) {
            return $this->{data}{$key->{name}}{$string};
        }
    }
    return 0;
}

sub check_config {
    my $this = shift;
    my $valid = 1;

    my $config = $this->{config};
    if ($config) {
        if ($config->{target} && $this->{valid_targets}{$config->{target}}) {
            $this->{target} = $config->{target};
        }
        my $keys_count = scalar(@{ $config->{keys} });
        if ($keys_count) {
            foreach my $key (@{ $config->{keys} }) {
                if ($key->{name} && $key->{key}) {
                    push @{ $this->{keys} }, $key;
                }
                else {
                    $valid = 0;
                }
            }
        }
        else {
            $valid = 0;
        }
    }

    if ($this->{target} && $valid) {
        # Enable dedup.
        $this->{dedup} = 1;
    }
}

1;
