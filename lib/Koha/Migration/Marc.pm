package Koha::Migration::Marc;

sub get {
    my ($class, $r, $field) = @_;

    my ($tag, $subfield) = split(/\$/, $field);

    if ($subfield) {
        return $r->field($tag)->subfield($subfield) if $r->field($tag) && $r->field($tag)->subfield($subfield);
    } else {
        return $r->field($tag)->data() if $r->field($tag);
    }
    return '';
}

1;
