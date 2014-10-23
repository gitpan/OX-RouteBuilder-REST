package OX::Meta::Role::Composite;
BEGIN {
  $OX::Meta::Role::Composite::AUTHORITY = 'cpan:STEVAN';
}
{
  $OX::Meta::Role::Composite::VERSION = '0.13';
}
use Moose::Role;
use namespace::autoclean;

use Moose::Util 'does_role';

with 'OX::Meta::Role::Role';

around apply_params => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig(@_);

    $self = Moose::Util::MetaRole::apply_metaroles(
        for => $self,
        role_metaroles => {
            application_to_class    => ['OX::Meta::Role::Application::ToClass'],
            application_to_role     => ['OX::Meta::Role::Application::ToRole'],
            application_to_instance => ['OX::Meta::Role::Application::ToInstance'],
        },
    );

    $self->_merge_routes;

    return $self;
};

sub _merge_routes {
    my $self = shift;

    my %routes;
    my %mounts;
    for my $role (@{ $self->get_roles }) {
        next unless does_role($role, 'OX::Meta::Role::Role');
        for my $route ($role->routes) {
            my $canonical = $route->canonical_path;
            if (exists $routes{$canonical}) {
                $routes{$canonical} = OX::Meta::Conflict->new(
                    path      => $canonical,
                    conflicts => [$routes{$canonical}, $route],
                );
            }
            else {
                $routes{$canonical} = $route;
            }
        }
        for my $mount ($role->mounts) {
            my $path = $mount->path;
            if (exists $mounts{$path}) {
                $mounts{$path} = OX::Meta::Conflict->new(
                    path      => $path,
                    conflicts => [$mounts{$path}, $mount],
                );
            }
            else {
                $mounts{$path} = $mount;
            }
        }
    }

    my %mixed;
    ROUTE: for my $route (values %routes) {
        for my $mount_path (keys %mounts) {
            my $mount = $mounts{$mount_path};
            (my $prefix = $mount_path) =~ s{/$}{};
            if ($route->path =~ m{^$mount_path\b}) {
                my @routes = $route->isa('OX::Meta::Conflict')
                    ? $route->conflicts
                    : $route;
                my @mounts = $mount->isa('OX::Meta::Conflict')
                    ? $mount->conflicts
                    : $mount;
                my $conflict = OX::Meta::Conflict->new(
                    path      => $route->canonical_path,
                    conflicts => [@routes, @mounts],
                );
                $self->_add_mixed_conflict($conflict);
                $mixed{$mount_path} = 1;
                next ROUTE;
            }
        }

        $self->_add_route($route);
    }

    delete $mounts{$_} for keys %mixed;

    for my $mount (values %mounts) {
        $self->_add_mount($mount);
    }
}

=for Pod::Coverage

=cut

1;
