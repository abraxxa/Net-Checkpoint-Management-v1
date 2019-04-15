package Net::Checkpoint::Management::v1::Role::ObjectMethods;

# ABSTRACT: Role for Checkpoint Management API version 1.x method generation

use 5.024;
use feature 'signatures';
use MooX::Role::Parameterized;
use Carp qw( croak );
use Clone qw( clone );
use Moo::Role; # last for cleanup

no warnings "experimental::signatures";

requires qw( _create _list _get _update _delete );

=head1 SYNOPSIS

    package Net::Cisco::FMC::v1;
    use Moo;
    use Net::Checkpoint::Management::v1::Role::ObjectMethods;

    Net::Checkpoint::Management::v1::Role::ObjectMethods->apply([
        {
            object   => 'packages',
            singular => 'package',
            create   => 'add-package',
            list     => 'show-packages',
            get      => 'show-package',
            update   => 'set-package',
            delete   => 'delete-package',
            list_key => 'packages',
        },
        {
            object   => 'accessrules',
            singular => 'accessrule',
            create   => 'add-access-rule',
            list     => 'show-access-rulebase',
            get      => 'show-access-rule',
            update   => 'set-access-rule',
            delete   => 'delete-access-rule',
            list_key => 'rulebase',
        },
    ]);

    1;

=head1 DESCRIPTION

This role adds methods for the REST methods of a specific object.

=cut

=method create_$singular

Takes a hashref of attributes.

Returns the created object as hashref.

Throws an exception on error.

=cut

=method list_$object

Takes optional query parameters.

Returns a hashref similar to the Checkpoint Management API but without the
'from' and 'to' keys.

Throws an exception on error.

As the API only allows fetching 500 objects at a time it works around that by
making multiple API calls.

=cut

=method get_$singular

Takes an object id and optional query parameters.

Returns the object as hashref.

Throws an exception on error.

=cut

=method update_$singular

Takes an object and a hashref of attributes.

Returns the updated object as hashref.

Throws an exception on error.

=cut

=method delete_$singular

Takes an object id.

Returns true on success.

Throws an exception on error.

=cut

=method find_$singular

Takes search and optional query parameters.

Returns the object as hashref on success.

Throws an exception on error.

As there is no API for searching by all attributes this method emulates this
by fetching all objects using the L</list_$object> method and performing the
search on the client.

=cut

role {
    my $params = shift;
    my $mop    = shift;

    $mop->method('create_' . $params->{singular} => sub ($self, $object_data) {
        return $self->_create(join('/',
            '/web_api',
            'v' . $self->api_version,
            $params->{create}
        ), $object_data);
    });

    $mop->method('list_' . $params->{object} => sub ($self, $query_params = {}) {
        return $self->_list(join('/',
            '/web_api',
            'v' . $self->api_version,
            $params->{list}
        ), $params->{list_key}, $query_params);
    });

    $mop->method('get_' . $params->{singular} => sub ($self, $id, $query_params = {}) {
        return $self->_get(join('/',
            '/web_api',
            'v' . $self->api_version,
            $params->{get}
        ), $query_params);
    });

    $mop->method('update_' . $params->{singular} => sub ($self, $object, $object_data) {
        my $id = $object->{id};
        return $self->_update(join('/',
            '/web_api',
            'v' . $self->api_version,
            $params->{update}
        ), $object, $object_data);
    });

    $mop->method('delete_' . $params->{singular} => sub ($self, $id) {
        return $self->_delete(join('/',
            '/web_api',
            'v' . $self->api_version,
            $params->{delete}
        ), {
            uid => $id,
        });
    });

    $mop->method('find_' . $params->{singular} => sub ($self, $search_params = {}, $query_params = {}) {
        my $listname = 'list_' . $params->{object};
        my $list_key = $params->{list_key};
        for my $object ($self->$listname({ 'details-level' => 'full', %$query_params })->{$list_key}->@*) {
            my $identical = 0;
            for my $key (keys $search_params->%*) {
                if ( ref $search_params->{$key} eq 'Regexp') {
                    if ( exists $object->{$key}
                        && $object->{$key} =~ $search_params->{$key}) {
                        $identical++;
                    }
                }
                else {
                    if ( exists $object->{$key}
                        && $object->{$key} eq $search_params->{$key}) {
                        $identical++;
                    }
                }
            }
            if ($identical == scalar keys $search_params->%*) {
                return $object;
            }
        }
        croak "object not found";
    });
};

1;
