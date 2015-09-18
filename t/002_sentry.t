use Test::Simple tests => 2;
use Mojolicious::Lite;
use Test::Mojo;

# Purpose: Test sentry helper

plugin Sentry => { sentry_dsn => 'http://key:secret@somewhere.com:9000/foo/123' };

get '/sentry' => sub {
    my $self = shift;
    return $self->render( text => $self->sentry->post_url );
};

my $t = Test::Mojo->new;
$t->get_ok('/sentry')
  ->status_is(200);
