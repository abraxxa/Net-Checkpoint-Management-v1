package Net::Checkpoint::Management::v1;

# ABSTRACT: Checkpoint Management API version 1.x client library

use 5.024;
use Moo;
use feature 'signatures';
use Types::Standard qw( ArrayRef Str );
use Carp::Clan qw(^Net::Checkpoint::Management::v1);
use Clone qw( clone );
use Net::Checkpoint::Management::v1::Role::ObjectMethods;

no warnings "experimental::signatures";

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Net::Checkpoint::Management::v1;

    my $cpmgmt = Net::Checkpoint::Management::v1->new(
        server      => 'https://cpmgmt.example.com',
        user        => 'username',
        passwd      => '$password',
        clientattrs => { timeout => 30 },
    );

    $cpmgmt->login;

=head1 DESCRIPTION

This module is a client library for the Checkpoint Management API version 1.x.
Currently it is developed and tested against version R80.10.

=cut

has 'user' => (
    isa => Str,
    is  => 'rw',
);
has 'passwd' => (
    isa => Str,
    is  => 'rw',
);

=attr api_versions

Returns a list of all available API versions which gets populated on the first
call.
Only works on API version 1.1 and higher.

=cut

has 'api_versions' => (
    is => 'lazy',
    isa => ArrayRef[Str],
);

sub _build_api_versions ($self) {
    my $res_versions = $self->post('/web_api/v1.1/show-api-versions', {});
    return $res_versions->data->{'supported-versions'};
}

=attr api_version

The API version used by all methods. Is automatically set to the highest
version available by the L</login> method.

=cut

has 'api_version' => (
    is  => 'rw',
    isa => Str,
);

with 'Net::Checkpoint::Management::v1::Role::REST::Client';

sub _error_handler ($self, $data) {
    my $error_message = (
        exists $data->{'blocking-errors'}
        && ref $data->{'blocking-errors'} eq 'ARRAY'
        && exists $data->{'blocking-errors'}->[0]
        && exists $data->{'blocking-errors'}->[0]->{message})
        ? $data->{'blocking-errors'}->[0]->{message}
        : $data->{message};
    croak($error_message);
}

sub _create ($self, $url, $object_data, $query_params = {}) {
    my $params = $self->user_agent->www_form_urlencode( $query_params );
    my $res = $self->post("$url?$params", $object_data);
    my $code = $res->code;
    my $data = $res->data;

    $self->_error_handler($data)
        unless $code == 200;
    return $data;
}

sub _list ($self, $url, $list_key, $query_params = {}) {
    # the API only allows 500 objects at a time
    # work around that by making multiple API calls
    my $offset = 0;
    my $limit = exists $query_params->{limit}
        ? $query_params->{limit}
        : 500;
    my $more_data_available = 1;
    my $response;
    while ($more_data_available) {
        my $res = $self->post($url, {
            offset => $offset,
            limit => $limit,
            %$query_params,
        });
        my $code = $res->code;
        my $data = $res->data;
        $self->_error_handler($data)
            unless $code == 200;

        # use first response for base structure of response
        if ($offset == 0) {
            $response = clone($data);
            delete $response->{from};
            delete $response->{to};
        }
        else {
            push $response->{$list_key}->@*, $data->{$list_key}->@*
                if exists $data->{$list_key} && ref $data->{$list_key} eq 'ARRAY';
        }

        # check if more data is available
        if ($offset + $limit < $data->{total}) {
            $more_data_available = 1;
            $offset += $limit;
        }
        else {
            $more_data_available = 0;
        }
    }

    # return response similar to Checkpoint API
    return $response;
}

sub _get ($self, $url, $query_params = {}) {
    my $res = $self->post($url, $query_params);
    my $code = $res->code;
    my $data = $res->data;

    $self->_error_handler($data)
        unless $code == 200;

    return $data;
}

sub _update ($self, $url, $object, $object_data) {
    my $updated_data = { %$object, %$object_data };

    my $res = $self->post($url, $updated_data);
    my $code = $res->code;
    my $data = $res->data;
    $self->_error_handler($data)
        unless $code == 200;

    return $data;
}

sub _delete ($self, $url, $object) {
    my $res = $self->post($url, $object);
    my $code = $res->code;
    my $data = $res->data;
    $self->_error_handler($data)
        unless $code == 200;

    return 1;
}

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
    {
        object   => 'networks',
        singular => 'network',
        create   => 'add-network',
        list     => 'show-networks',
        get      => 'show-network',
        update   => 'set-network',
        delete   => 'delete-network',
        list_key => 'objects',
    },
    {
        object   => 'hosts',
        singular => 'host',
        create   => 'add-host',
        list     => 'show-hosts',
        get      => 'show-host',
        update   => 'set-host',
        delete   => 'delete-host',
        list_key => 'objects',
    },
    {
        object   => 'access_roles',
        singular => 'access_role',
        create   => 'add-access-role',
        list     => 'show-access-roles',
        get      => 'show-access-role',
        update   => 'set-access-role',
        delete   => 'delete-access-role',
        list_key => 'objects',
    },
    {
        object   => 'services_tcp',
        singular => 'service_tcp',
        create   => 'add-service-tcp',
        list     => 'show-services-tcp',
        get      => 'show-service-tcp',
        update   => 'set-service-tcp',
        delete   => 'delete-service-tcp',
        list_key => 'objects',
    },
    {
        object   => 'services_udp',
        singular => 'service_udp',
        create   => 'add-service-udp',
        list     => 'show-services-udp',
        get      => 'show-service-udp',
        update   => 'set-service-udp',
        delete   => 'delete-service-udp',
        list_key => 'objects',
    },
    {
        object   => 'services_icmp',
        singular => 'service_icmp',
        create   => 'add-service-icmp',
        list     => 'show-services-icmp',
        get      => 'show-service-icmp',
        update   => 'set-service-icmp',
        delete   => 'delete-service-icmp',
        list_key => 'objects',
    },
    {
        object   => 'services_icmpv6',
        singular => 'service_icmpv6',
        create   => 'add-service-icmp6',
        list     => 'show-services-icmp6',
        get      => 'show-service-icmp6',
        update   => 'set-service-icmp6',
        delete   => 'delete-service-icmp6',
        list_key => 'objects',
    },
    {
        object   => 'services_other',
        singular => 'service_other',
        create   => 'add-service-other',
        list     => 'show-services-other',
        get      => 'show-service-other',
        update   => 'set-service-other',
        delete   => 'delete-service-other',
        list_key => 'objects',
    },
    {
        object   => 'service_groups',
        singular => 'service_group',
        create   => 'add-service-group',
        list     => 'show-service-groups',
        get      => 'show-service-group',
        update   => 'set-service-group',
        delete   => 'delete-service-group',
        list_key => 'objects',
    },
    {
        object   => 'sessions',
        singular => 'session',
        list     => 'show-sessions',
        get      => 'show-session',
        update   => 'set-session',
        list_key => 'objects',
    },
]);

=method login

Logs into the Checkpoint Manager API using version 1.

=cut

sub login($self) {
    my $res = $self->post('/web_api/v1/login', {
        user     => $self->user,
        password => $self->passwd,
    });
    if ($res->code == 200) {
        my $api_version = $res->data->{'api-server-version'};
        $self->api_version($api_version);
        $self->set_persistent_header('X-chkp-sid',
            $res->data->{sid});
    }
    else {
        $self->_error_handler($res->data);
    }
}

=method logout

Logs out of the Checkpoint Manager API using version 1.

=cut

sub logout($self) {
    my $res = $self->post('/web_api/v1/logout', {});
    my $code = $res->code;
    my $data = $res->data;
    $self->_error_handler($data)
        unless $code == 200;
}

=method publish

Publishes all previously submitted changes.
Returns the task id on success.

=cut

sub publish($self) {
    my $res = $self->post('/web_api/v' . $self->api_version . '/publish', {});
    my $code = $res->code;
    my $data = $res->data;
    $self->_error_handler($data)
        unless $code == 200;

    return $data->{'task-id'};
}

=method discard

Discards all previously submitted changes.
Returns a hashref containing the operation status messange and the number of
discarded changes.

=cut

sub discard($self) {
    my $res = $self->post('/web_api/v' . $self->api_version . '/discard', {});
    my $code = $res->code;
    my $data = $res->data;
    $self->_error_handler($data)
        unless $code == 200;

    return $data;
}

1;
