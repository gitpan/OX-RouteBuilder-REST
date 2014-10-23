package OX::RouteBuilder::HTTPMethod;
BEGIN {
  $OX::RouteBuilder::HTTPMethod::AUTHORITY = 'cpan:STEVAN';
}
{
  $OX::RouteBuilder::HTTPMethod::VERSION = '0.13';
}
use Moose;
use namespace::autoclean;
# ABSTRACT: OX::RouteBuilder which routes to a method in a controller based on the HTTP method

use Try::Tiny;

with 'OX::RouteBuilder';


sub compile_routes {
    my $self = shift;
    my ($app) = @_;

    my $spec = $self->route_spec;
    my $params = $self->params;

    my ($defaults, $validations) = $self->extract_defaults_and_validations($params);
    $defaults = { %$spec, %$defaults };

    my $target = sub {
        my ($req) = @_;

        my $match = $req->mapping;
        my $a = $match->{action};

        my $err;
        my $s = try { $app->fetch($a) } catch { ($err) = split "\n"; undef };
        return [
            500,
            [],
            ["Cannot resolve $a in " . blessed($app) . ": $err"]
        ] unless $s;

        my $component = $s->get;
        my $method = lc($req->method);

        if ($component->can($method)) {
            return $component->$method(@_);
        }
        elsif ($component->can('any')) {
            return $component->any(@_);
        }
        else {
            return [
                500,
                [],
                ["Component $component has no method $method"]
            ];
        }
    };

    return {
        path        => $self->path,
        defaults    => $defaults,
        target      => $target,
        validations => $validations,
    };
}

sub parse_action_spec {
    my $class = shift;
    my ($action_spec) = @_;

    return if ref($action_spec);
    return unless $action_spec =~ /^(\w+)$/;

    return {
        action => $1,
        name   => $action_spec,
    };
}

__PACKAGE__->meta->make_immutable;


1;

__END__

=pod

=head1 NAME

OX::RouteBuilder::HTTPMethod - OX::RouteBuilder which routes to a method in a controller based on the HTTP method

=head1 VERSION

version 0.13

=head1 SYNOPSIS

  package MyApp;
  use OX;

  has controller => (
      is  => 'ro',
      isa => 'MyApp::Controller',
  );

  router as {
      route '/' => 'controller';
  };

=head1 DESCRIPTION

This is an L<OX::RouteBuilder> which allows to a controller class based on the
HTTP method used in the request. The C<action_spec> should be a string
corresponding to a service which provides a controller instance. When a request
is made for the given path, it will look in that class for a method which
corresponds to the lowercased version of the HTTP method used in the request
(for instance, C<get>, C<post>, etc). If no method is found, it will fall back
to looking for a method named C<any>. If that isn't found either, an error will
be raised.

C<action> will automatically be added to the route as a default, as well as
C<name> (which will be set to the same thing as C<action>).

=for Pod::Coverage compile_routes
  parse_action_spec

=head1 AUTHORS

=over 4

=item *

Stevan Little <stevan.little@iinteractive.com>

=item *

Jesse Luehrs <doy@tozt.net>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
