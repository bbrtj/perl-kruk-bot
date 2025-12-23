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
		foreach my $key (sort keys $object->%*) {
			if (!ref $object->{$key} && any { $key eq $_ } TEXT_OBJECTS->@*) {
				push @results, [$key, $object, $where]
			}
			else {
				push @results, $self->_extract_prompts($object->{$key}, $where);
			}
		}
	}
	elsif ($ref eq 'ARRAY') {
		foreach my $value ($object->@*) {
			push @results, $self->_extract_prompts($value, $where);
		}
	}

	return @results;
}

# tries to approximate the number of tokens (always underestimates). Based on
# the result, decides where to put cache breakpoints
sub process_cache ($self, $ctx, $request_data)
{
	my @prompts = map { $self->_extract_prompts($request_data->{$_}, $_) } CACHE_ORDER->@*;
	my $cache_threshold = $request_data->{model} =~ /haiku/i ? MIN_CACHE_TOKENS_HAIKU : MIN_CACHE_TOKENS_SONNET;
	my $tokens = $prompts[0] && $prompts[0][2] eq CACHE_ORDER->[0] ? TOOLS_PROMPT_TOKENS : 0;
	my $breakpoints = 0;
	my $last_breakpoint_tokens = 0;

	my sub add_breakpoint ($prompt)
	{
		return !!1 if defined $prompt->[1]{cache_control}{type};
		return !!0 if $breakpoints == MAX_BREAKPOINTS;
		$breakpoints += 1;
		$last_breakpoint_tokens = $tokens;

		$self->bot_instance->log->debug("Setting a cache breakpoint in $prompt->[2] block");
		$prompt->[1]{cache_control}{type} = 'ephemeral';
		return !!1;
	}

	my $messages_cached = !!0;
	my $last;
	my $message_number = 0;
	foreach my $prompt (@prompts) {
		my $tokens_in_prompt = length($prompt->[1]->{$prompt->[0]}) / CHARACTERS_PER_TOKEN;

		# total tokens up to this point exceeded cache threshold, and the type changed (like system -> messages)
		if (defined $last && $last->[2] ne $prompt->[2] && $tokens > $cache_threshold) {
			add_breakpoint($last);
		}

		$tokens += $tokens_in_prompt;

		if ($prompt->[2] eq CACHE_ORDER->[-1]) {
			++$message_number;

			# this prompt alone is big enough to justify caching
			my $big_prompt = $tokens_in_prompt > $cache_threshold;

			# if we saved up enough tokens, we may cache
			my $checkpoint_message = $tokens - $last_breakpoint_tokens > $cache_threshold * 2;

			if ($big_prompt || $checkpoint_message) {
				$messages_cached = add_breakpoint($prompt) || $messages_cached;
			}
		}

		$last = $prompt;
	}

	return {
		expected_tokens => $tokens,
		messages_cached => $messages_cached,
		breakpoints => $breakpoints,
	};
}

