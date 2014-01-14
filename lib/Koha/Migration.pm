package Koha::Migration;

use strict;
use warnings;
use C4::Context;
use YAML;
use Switch;

use Koha::Migration::Dedup;
use Koha::Migration::Plugins;

use constant CONF_PATH => '/config';

sub new {
    my ($class, $options) = @_;

    my $this = {
        'base_path' => $options->{Bin},
        'confirm' => $options->{confirm},
        'max' => $options->{max},
        'skip_dedup' => $options->{skip_dedup},
        'config' => {},
    };
    return bless $this, $class;
}

$|=1;
sub migrate {
    my $this = shift;

    # Init Koha object.
    my $koha = Koha::Migration::Koha->new();

    # Init Plugins API.
    my $plugins = Koha::Migration::Plugins->new($this->{base_path});

    # Load configuration
    $this->load_config;

    # Init dedup for biblios.
    my $dedup = Koha::Migration::Dedup->new($this->{config}{bibliodedup});
    unless ($this->{skip_dedup}) {
        $dedup->init();
    }

    # Process biblio files..
    print "Start migrating biblios\n" if $main::verbose;
    my $files = $this->{config}{bibliofiles};
    foreach my $file (@$files) {
        my ($total, $biblios) =  $this->loadFile($file);
        next unless $biblios;

        # Stores migration context for this biblio.
        # Hooks are able to change it.
        my $context = {
            'insert' => 1,
            'file' => $file->{path},
            'count' => 0,
            'total' => $total,
            'duplicates' => 0,
        };

        while ( my $biblio = $biblios->next ) {
            $context->{count}++;
            if ($main::verbose) {
                my $el = $context->{count} == $context->{total} ? "\n" : "\r";
                print "$context->{file}: $context->{count}/$context->{total}$el" if $main::verbose;
            }

            # Replace insert to 1 to save biblio.
            $context->{insert} = 1;

            # 1) Use MARC::Transform ?;

            # Call hook_biblio_process().
            $plugins->callPlugins('biblio_transformed', [$biblio, $context]);

            # Match existing biblios in koha.
            my $biblionumber = $dedup->match($biblio) unless $this->{skip_dedup};

            # Biblio is a duplicate.
            if ($biblionumber) {
                $plugins->callPlugins('biblio_is_duplicate', [$biblio, $context, $biblionumber]);
                $context->{duplicates}++;
            }

            # save biblio in koha.
            if ($context->{insert} && $this->{confirm}) {
                my $biblionumber = $koha->addBiblioItems($biblio);

                # Biblio has been saved in koha. So add it
                # to the dedup data.
                if ($biblionumber) {
                    $dedup->add($biblio, $biblionumber) unless $this->{skip_dedup};
                }
            }
        }
    }
}

sub loadFile {
    my ($this, $file) = @_;

    my $path = $this->{base_path} . '/data/' . $file->{path};
    die "unable to load " . $file->{path} unless -r $path;

    my $parser = $file->{parser};
    my $biblios;
    my $count = 0;
    switch ($parser) {
        case 'mrc' {
            $biblios = MARC::File::USMARC->in($path);
            # Loop a firt time over biblios.
            while (my $biblio = $biblios->next) {
                $count++;
            }
            $biblios->close();
            # Open file again to replace the pointer
            # at the begining of the file.
            $biblios = MARC::File::USMARC->in($path);
        }
        # Write here case 'csv'.
    }
    return ($count, $biblios);

}

sub load_config {
    my $this = shift;

    print "Loading configuration..." if $main::verbose;
    my $config_file = $this->{base_path} . CONF_PATH . '/config.yaml';
    my $config = YAML::LoadFile($config_file)
        or die "unable to load $config_file";

    $this->{config} = $config;
    print " ok\n" if $main::verbose;
}

1;
