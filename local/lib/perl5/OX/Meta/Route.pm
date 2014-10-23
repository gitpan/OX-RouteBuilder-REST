package OX::Meta::Route;
BEGIN {
  $OX::Meta::Route::AUTHORITY = 'cpan:STEVAN';
}
{
  $OX::Meta::Route::VERSION = '0.13';
}
use Moose;
use namespace::autoclean;

with 'OX::Meta::Role::Path';

has class => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has route_spec => (
    is       => 'ro',
    required => 1,
);

has params => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

sub router_config {
    my $self = shift;

    return {
        path       => $self->path,
        class      => $self->class,
        route_spec => $self->route_spec,
        params     => $self->params,
    };
}

sub type { 'route' }

__PACKAGE__->meta->make_immutable;

=for Pod::Coverage
  router_config
  type

=cut

1;
