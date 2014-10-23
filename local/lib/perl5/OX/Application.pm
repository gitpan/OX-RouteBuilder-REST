package OX::Application;
BEGIN {
  $OX::Application::AUTHORITY = 'cpan:STEVAN';
}
{
  $OX::Application::VERSION = '0.13';
}
use Moose 2.0200;
use namespace::autoclean;
# ABSTRACT: base class for OX applications

use Bread::Board;
use Plack::Middleware::HTTPExceptions;
use Plack::Util;
use Scalar::Util 'weaken';
use Try::Tiny;

use OX::Util;

extends 'Bread::Board::Container';


has name => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { shift->meta->name },
);

sub BUILD {
    my $_self = shift;
    weaken(my $self = $_self);

    container $self => as {
        service Middleware => (
            block => sub {
                my $s = shift;
                $self->build_middleware($s);
            },
            dependencies => $self->middleware_dependencies,
        );

        service App => (
            block => sub {
                my $s = shift;

                my $app = $self->build_app($s);

                my @middleware = (
                    sub {
                        my ($app) = @_;

                        return sub {
                            my $env = shift;

                            my $res = $app->($env);

                            Plack::Util::response_cb(
                                $res,
                                sub {
                                    return sub {
                                        my $content = shift;

                                        # flush all services that are
                                        # request-scoped after the response is
                                        # returned
                                        $self->_flush_request_services
                                            unless defined $content;

                                        return $content;
                                    };
                                }
                            );

                            return $res;
                        };
                    },
                    @{ $s->param('Middleware') },
                    Plack::Middleware::HTTPExceptions->new(rethrow => 1),
                );

                for my $middleware (reverse @middleware) {
                    $app = OX::Util::apply_middleware($app, $middleware);
                }

                $app;
            },
            dependencies => {
                Middleware => 'Middleware',
                %{ $self->app_dependencies },
            }
        );
    };
}


sub build_middleware { [] }


sub middleware_dependencies { {} }


sub build_app {
    my $self = shift;
    confess(blessed($self) . " must implement the build_app method");
}


sub app_dependencies { {} }


sub to_app {
    my $self = shift;
    return $self->resolve(service => 'App');
}

sub _flush_request_services {
    my $self = shift;

    for my $service ($self->get_service_list) {
        my $injection = $self->get_service($service);
        if ($injection->does('Bread::Board::LifeCycle::Request')) {
            $injection->flush_instance;
        }
    }
}

__PACKAGE__->meta->make_immutable;


1;

__END__

=pod

=head1 NAME

OX::Application - base class for OX applications

=head1 VERSION

version 0.13

=head1 SYNOPSIS

  package MyApp;
  use Moose;
  extends 'OX::Application';

  sub build_app {
      return sub { [ 200, [], ["Hello world"] ] };
  }

  MyApp->new->to_app; # returns the PSGI coderef

=head1 DESCRIPTION

This class provides the base set of functionality for OX applications.
OX::Application is a subclass of L<Bread::Board::Container>, so all
L<Bread::Board> functionality is available through it.

By default, the container holds two services:

=over 4

=item Middleware

This service provides an arrayref of middleware to be applied, in order, to the
app (the first middleware in the array will be the outermost middleware in the
final built app). It is built via the C<build_middleware> and
C<middleware_dependencies> methods, described below.

Middleware can be specified as either a coderef (which is expected to accept an
app coderef as an argument and return a new app coderef), the name of a
subclass of L<Plack::Middleware>, or a L<Plack::Middleware> instance.

=item App

This service provides the actual L<PSGI> coderef for the application. It is
built via the C<build_app> and C<app_dependencies> methods described below, and
applies the middleware from the C<Middleware> service afterwards. It also
applies L<Plack::Middleware::HTTPExceptions> as the innermost middleware, so
your app can throw L<HTTP::Throwable> or L<HTTP::Exception> objects and have
them work properly.

=back

You can add any other services or subcontainers you like, and can use them in
the construction of your app by overriding C<build_middleware>,
C<middleware_dependencies>, C<build_app>, and C<app_dependencies>.

=head1 METHODS

=head2 build_middleware($service)

This method can be overridden in your app to provide an arrayref of middleware
to be applied to the final application. It is passed the C<Middleware> service
object, so that you can access the resolved dependencies you specify in
C<middleware_dependencies>.

=head2 middleware_dependencies

This method returns a hashref of dependencies, as described in L<Bread::Board>.
The arrayref form of dependency specification is not currently supported. These
dependencies can be accessed in the C<build_middleware> method.

=head2 build_app($service)

This method must be overridden by your app to return a L<PSGI> coderef. It is
passed the C<App> service object, so that you can access the resolved
dependencies you specify in C<app_dependencies>.

=head2 app_dependencies

This method returns a hashref of dependencies, as described in L<Bread::Board>.
The arrayref form of dependency specification is not currently supported. These
dependencies can be accessed in the C<build_app> method.

=head2 to_app

This method returns the final L<PSGI> application, after all middleware have
been applied. This method is just a shortcut for
C<< $app->resolve(service => 'App') >>.

=for Pod::Coverage BUILD

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
