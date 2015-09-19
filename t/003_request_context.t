use Mojolicious::Lite; # imports use strict/use warnings
use Test::More;
use Test::Mojo;
use Sentry::Raven;

# Purpose: Test sentryCaptureMessage helper

# Create a minimal Mojo lite app that throws exceptions
# exception.html.ep is defined later in __DATA__
plugin Sentry	=> { sentry_dsn => 'http://key:secret@somewhere.com:9000/foo/123' };
get '/500'		=> sub { die "raise hell" };
# App over

subtest "it captures the exception" => sub {
	my ($msg, %context) = capture_exception();
	like $msg => qr/raise hell/;
};

subtest 'it includes the http request in the event' => sub {
	my ($msg, %context) = capture_exception();

	ok my $http = $context{'sentry.interfaces.Http'};
	is   $http->{method}	=> 'GET',		'method';
	like $http->{url}		=> qr/^http/,	'Sentry requires an absolute url';
	is   $http->{data}		=> '',			'Context includes data';
};

subtest 'it includes a stacktrace in the event' => sub {
	my ($msg, %context) = capture_exception();

	ok my $stack = $context{'sentry.interfaces.Stacktrace'}, 'stacktrace included';
	ok my (@frames) = @{$stack->{frames}}, 'it has frames';

	cmp_ok scalar(@frames), '>', 1, 'it includes the full stracktrace';

	subtest 'all frames have a filename' => sub {
		my @invalid_frames = grep { !$_->{filename} } @frames;
		ok(!@invalid_frames)
			or diag("Some frames are missing a filename: ", explain(\@invalid_frames));
	};

	subtest 'all frames have a line number' => sub {
		my @invalid_frames = grep { !$_->{lineno} } @frames;
		ok(!@invalid_frames)
			or diag("Some frames are missing a lineno: ", explain(\@invalid_frames));
	};

	subtest 'all frames have a function' => sub {
		my @invalid_frames = grep { !$_->{function} } @frames;
		ok(!@invalid_frames)
			or diag("Some frames are missing a function: ", explain(\@invalid_frames));
	};
};

done_testing;

sub capture_exception {
	my ($url, @params) = @_;

	# Intercept the message that Sentry::Raven receives
	no warnings 'redefine';
	my @captured_message;
	local *Sentry::Raven::capture_message = sub {
		my ($self, @args) = @_;
		(@captured_message) = (@args);
	};

	# Get Mojo-lite to raise an exception
	Test::Mojo->new->get_ok($url || '/500', @params);
	return @captured_message;
}

__DATA__

@@ exception.html.ep
% warn "rendering";
% sentryCaptureMessage $exception;
Exception caught
