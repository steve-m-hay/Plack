package Plack::App::Cascade;
use strict;
use base qw(Plack::Component);

use Plack::Util::Accessor qw(apps catch codes);

sub add {
    my $self = shift;
    $self->apps([]) unless $self->apps;
    push @{$self->apps}, @_;
}

sub prepare_app {
    my $self = shift;
    my %codes = map { $_ => 1 } @{ $self->catch || [ 404 ] };
    $self->codes(\%codes);
}

sub call {
    my($self, $env) = @_;

    return sub {
        my $respond = shift;

        my $res = [ 404, [ 'Content-Type' => 'text/html' ], [ '404 Not Found' ] ];

        for my $app (@{$self->apps || []}) {
            $res = $app->($env);
            if (ref $res eq 'CODE') {
                my $done;
                $res->(sub {
                    my $res = shift;
                    unless ($self->codes->{$res->[0]}) {
                        $done = 1;
                        return $respond->($res);
                    }
                });
                return if $done;
            } else {
                last unless $self->codes->{$res->[0]};
            }
        }

        return $respond->($res);
    };
}

1;

__END__

=head1 NAME

Plack::App::Cascade - Cascadable compound application

=head1 SYNOPSIS

  use Plack::App::Cascade;
  use Plack::App::URLMap;
  use Plack::App::File;

  # Serve static files from multiple search paths
  my $cascade = Plack::App::Cascade->new;
  $cascade->add( Plack::App::File->new(root => "/www/example.com/foo")->to_app );
  $cascade->add( Plack::App::File->new(root => "/www/example.com/bar")->to_app );

  my $app = Plack::App::URLMap->new;
  $app->map("/static", $cascade);
  $app->to_app;

=head1 DESCRIPTION

Plack::App::Cascade is a Plack middleware component that compounds
several apps and tries them to return the first response that is not
404.

Note that this application doesn't support I<psgi.streaming>
interface.

=head1 METHODS

=over 4

=item new

  $app = Plack::App::Cascade->new(apps => [ $app1, $app2 ]);

Creates a new Cascade application.

=item add

  $app->add($app1);
  $app->add($app2, $app3);

Appends a new application to the list of apps to try. You can pass the
multiple apps to the one C<add> call.

=item catch

  $app->catch([ 403, 404 ]);

Sets which error codes to catch and process onwards. Defaults to C<404>.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Plack::App::URLMap> Rack::Cascade

=cut
