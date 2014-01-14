package Koha::Migration::Plugins;

use strict;
use warnings;

sub new {
    my ($class, $Bin) = @_;

    my $this = {
        'base_path' => $Bin,
    };

    my $plugins = getPlugins("$Bin/plugins");

    $this->{'plugins'} = $plugins->{'plugins'};
    $this->{'plugin_errors'} = $plugins->{'plugin_errors'};

    if (keys %{ $this->{plugin_errors} } && $main::verbose) {
        print "Error(s) in plugin(s):\n";
        print Data::Dumper::Dumper($this->{plugin_errors});
    }

    return bless $this, $class;
}

sub getPlugins {
    my $plugins_dir = shift;

    my $plugins = {
        'plugins' => [],
        'plugin_errors' => {},
    };

    if (-d $plugins_dir) {
        opendir my($dh), $plugins_dir or die "Couldn't open dir '$plugins_dir': $!";

        while (defined(my $name = readdir $dh)) {
            unless ($name =~ /^\./) {
                unless (-d "$plugins_dir/$name") {
                    push @{ $plugins->{'plugin_errors'}{$name} }, "Invalid directory";
                    next;
                }

                my $plugin;
                if (-r "$plugins_dir/$name/plugin.yaml") {
                    $plugin = YAML::LoadFile("$plugins_dir/$name/plugin.yaml")
                        or push @{ $plugins->{'plugin_errors'}{$name} }, "file $name/plugin.yaml not readable";
                }

                # If name, file or package are not set, we use $name.
                $plugin->{name} ||= $name;
                $plugin->{file} ||= "$name.pm";
                $plugin->{package} ||= $name;

                my $require = "$plugins_dir/$name/" .  $plugin->{file};
                eval{ require $require; };
                if ($@) {
                    push @{ $plugins->{'plugin_errors'}{$name} }, $@;
                    next;
                }
                $plugin->{require} = $require;
                push @{ $plugins->{plugins} }, $plugin;
            }
        }
    }
    return $plugins;
}

sub callPlugins {
    #my ($patron_object, $hook, $args) = @_;
    my ($this, $hook, $args) = @_;
    my $plugins = $this->{plugins};

    foreach my $plugin ( @$plugins ) {
        eval{ require $plugin->{require}; };
        if ($@) {
            warn "Unable to use " . $plugin->{name} . " plugin: $@";
            next;
        }
        my $func = $plugin->{name} . "_" . $hook;
        my $package = $plugin->{package};
        if ( defined( $package->can($func) ) ) {
            execHook($package, $func, $args);
        }
    }
}

sub execHook {
    no strict 'refs';
    my ( $ns, $sub, $args ) = @_;

    my @args = ();
    if (ref($args) ne 'ARRAY') {
        push @args, $args;
    }
    else {
        @args = @{ $args };
    }

    *{"$ns\::$sub"}->( @args );
}

1;
