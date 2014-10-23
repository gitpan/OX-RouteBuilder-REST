package OX::Meta::Conflict;
BEGIN {
  $OX::Meta::Conflict::AUTHORITY = 'cpan:STEVAN';
}
{
  $OX::Meta::Conflict::VERSION = '0.13';
}
use Moose;
use namespace::autoclean;

with 'OX::Meta::Role::Path';

has conflicts => (
    traits  => ['Array'],
    isa     => 'ArrayRef[OX::Meta::Role::Path]',
    default => sub { [] },
    handles => {
        conflicts    => 'elements',
        add_conflict => 'push',
    },
);

sub message {
    my $self = shift;

    my @descs = map {
        $_->type . " " . $_->path . " (" . $_->definition_location . ")"
    } $self->conflicts;

    return "Conflicting paths found: " . join(', ', @descs);
}

sub type { 'conflict' }

__PACKAGE__->meta->make_immutable;

=for Pod::Coverage
  message
  type

=cut

1;
