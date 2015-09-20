package Mojolicious::Plugin::Sentry;

use Mojo::Base 'Mojolicious::Plugin';
use Sentry::Raven;
use Cwd ();

our $VERSION = 0.11;

has qw/mojo_lib_dir/;
has qw/sentry/;

sub register {
	my ($plugin, $app, $conf)  = @_;

	$plugin->mojo_lib_dir( Cwd::abs_path($app->home->mojo_lib_dir) );
	$plugin->sentry( Sentry::Raven->new(%$conf) );

	$app->helper(sentry => sub {
		$plugin->sentry;
	});

	$app->helper(sentryCaptureMessage => sub {
		my ($self, $data, %p) = @_;

		if (ref $data eq 'Mojo::Exception') {
			my (@frames) = $plugin->_exception_to_stacktrace_context($data);
			my (@req)    = $plugin->_req_to_http_context($self->req);

			my $sentry = $plugin->sentry;
			$sentry->capture_message(
				$data->message,
				$sentry->request_context(@req),
				$sentry->stacktrace_context(\@frames),
				%p,
			);
		} else {
			$plugin->sentry->capture_message(
				$data,
				%p,
			);
		}
	});
}

sub _req_to_http_context {
	my ($self, $req) = @_;

	return (
		$req->url->to_abs->to_string,
		method => $req->method,
		data   => $req->params->to_string,
		headers => { map {$_ => ~~$req->headers->header($_)} @{$req->headers->names} },
	);
}

sub _exception_to_stacktrace_context {
	my ($self, $exception) = @_;

	my $mojo_lib_dir = $self->mojo_lib_dir;

	# Build a list of frames ordered by most recent call first
	my @frames = map {
		{
			# frames must contain at least one of filename, function or module
			# skipping module ($_->[0]) because the function is fully qualified
			filename => $_->[1],
			lineno   => $_->[2],
			function => $_->[3],
			in_app   => Cwd::abs_path($_->[1]) =~ m{^\Q$mojo_lib_dir\E/} ? 0 : 1,
		},
	} @{ $exception->frames };

	# Include the line of source code that raised the exception
	$frames[0]->{context_line} = $exception->line->[1];
	$frames[0]->{pre_context}  = [
		map {$_->[1]} @{$exception->lines_before}
	];
	$frames[0]->{post_context} = [
		map {$_->[1]} @{$exception->lines_after}
	];

	# Sentry wants the oldest call first
	return reverse @frames;
}

1;

=pod

=head1 NAME

Mojolicious::Plugin::Sentry - A perl sentry client for Mojolicious

=head1 VERSION

version 0.1

=head1 SYNOPSIS

	# Mojolicious::Lite
	plugin 'sentry' => {
		sentry_dsn  => 'DSN',
		server_name => 'HOSTNAME',
		logger      => 'root',
		platform    => 'perl',
	};

	# Mojolicious with config
	$self->plugin('sentry' => {
		sentry_dsn  => 'DSN',
		server_name => 'HOSTNAME',
		logger      => 'root',
		platform    => 'perl',
	});

	# template: tmpl/exception.html.ep
	% sentryCaptureMessage $exception;

=head1 DESCRIPTION

Mojolicious::Plugin::Sentry is a plugin for the Mojolicious web framework which allow you use Sentry L<https://getsentry.com>.

See also L<Sentry::Raven|https://metacpan.org/pod/Sentry::Raven> for configuration parameters on init plugin and for use sentryCaptureMessage.

=head1 SEE ALSO

L<Sentry::Raven|https://metacpan.org/pod/Sentry::Raven>

=head1 SOURCE REPOSITORY

L<https://github.com/likhatskiy/Mojolicious-Plugin-Sentry>

=head1 AUTHOR

Alexey Likhatskiy, <likhatskiy@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 "Alexey Likhatskiy"

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
