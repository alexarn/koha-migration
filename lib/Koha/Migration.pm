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
        'verbose' => $options->{verbose},
        'max' => $options->{max},
        'config' => {},
    };
    return bless $this, $class;
}

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
    $dedup->init();

    # Process biblio files..
    my $files = $this->{config}{bibliofiles};
    foreach my $file (@$files) {
       my $biblios =  $this->loadFile($file);
       next unless $biblios;

       # Stores migration context for this biblio.
       # Hooks are able to change it.
       my $context = {
           'insert' => 1,
       };

       while ( my $biblio = $biblios->next ) {
           # 1) Use MARC::Transform ?;

           # Call hook_biblio_process().
           $plugins->callPlugins('biblio_transformed', [$biblio, $context]);

           # Match existing biblios in koha.
           my $biblionumber = $dedup->match($biblio);

           # Biblio is a duplicate.
           $plugins->callPlugins('biblio_is_duplicate', [$biblio, $context]) if $biblionumber;

           # save biblio in koha.
           if ($context->{insert} && $this->{confirm}) {
               my $biblionumber = $koha->addBiblioItems($biblio);

               # Biblio has been saved in koha. So add it
               # to the dedup data.
               $dedup->add($biblio, $biblionumber) if $biblionumber;
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
    switch ($parser) {
        case 'mrc' {
            $biblios = MARC::File::USMARC->in($path);
        }
        # Write here case 'csv'.
    }
    return $biblios;

}

sub load_config {
    my $this = shift;

    my $config_file = $this->{base_path} . CONF_PATH . '/config.yaml';
    my $config = YAML::LoadFile($config_file)
        or die "unable to load $config_file";

    $this->{config} = $config;
}

1;