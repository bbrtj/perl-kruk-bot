package Bot::Cache;

use v5.40;

use Mooish::Base;
use List::Util qw(any);

use constant CACHE_ORDER => [qw(tools system messages)];
use constant TEXT_OBJECTS => [qw(text description)];
use constant MAX_BREAKPOINTS => 4;
use constant MIN_CACHE_TOKENS_SONNET => 1024;
use constant MIN_CACHE_TOKENS_HAIKU => 2048;
use constant TOOLS_PROMPT_TOKENS => 300;    # approx
use constant CHARACTERS_PER_TOKEN => 4;    # approx
use constant CACHE_LIFETIME => 5 * 60;

has param 'bot_instance' => (
	isa => InstanceOf ['Bot'],
);

sub _extract_prompts ($self, $object, $where)
{
	my $ref = ref $object;
	my @results;
	if ($ref eq 'HASH') {
		my $got_key;
		foreach my $key (sort keys $object->%*) {
			if (any { $key eq $_ } TEXT_OBJECTS->@*) {
				$got_key = $key;
			}
			else {
				push @results, $self->_extract_prompts($object->{$key}, $where);
			}
		}

		push @results, [$got_key, $object, $where]
			if $got_key;
	}
	elsif ($ref eq 'ARRAY') {
		foreach my $value ($object->@*) {
			push @results, $self->_extract_prompts($value, $where);
		}
	}

	return @results;
}

sub process_cache ($self, $ctx, $request_data)
{
	my @prompts = map { $self->_extract_prompts($request_data->{$_}, $_) } CACHE_ORDER->@*;
	my $cache_threshold = $request_data->{model} =~ /haiku/i ? MIN_CACHE_TOKENS_HAIKU : MIN_CACHE_TOKENS_SONNET;
	my $tokens = $prompts[0] && $prompts[0][2] eq CACHE_ORDER->[0] ? TOOLS_PROMPT_TOKENS : 0;

	my sub add_breakpoint ($prompt)
	{
		state $breakpoints = MAX_BREAKPOINTS;
		return !!0 if --$breakpoints <= 0;

		$self->bot_instance->log->debug("Setting a cache breakpoint in $prompt->[2] block");
		$prompt->[1]{cache_control}{type} = 'ephemeral';
		return !!1;
	}

	my $messages_cached = !!0;
	my $last;
	foreach my $prompt (@prompts) {
		my $tokens_in_prompt = length($prompt->[1]->{$prompt->[0]}) / CHARACTERS_PER_TOKEN;

		# total tokens up to this point exceeded cache threshold, and the type changed (like system -> messages)
		if (defined $last && $last->[2] ne $prompt->[2] && $tokens > $cache_threshold) {
			add_breakpoint($last);
		}

		$tokens += $tokens_in_prompt;

		# this prompt alone is big enough to justify caching
		if ($prompt->[2] eq CACHE_ORDER->[-1] && $tokens_in_prompt > $cache_threshold) {
			$messages_cached ||= add_breakpoint($prompt);
		}
		$last = $prompt;
	}

	return {
		expected_tokens => $tokens,
		messages_cached => $messages_cached,
	};
}

