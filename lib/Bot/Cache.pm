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

# tries to approximate the number of tokens (always underestimates). Based on
# the result, decides where to put cache breakpoints
sub process_cache ($self, $ctx, $request_data)
{
	my @prompts = map { $self->_extract_prompts($request_data->{$_}, $_) } CACHE_ORDER->@*;
	my $cache_threshold = $request_data->{model} =~ /haiku/i ? MIN_CACHE_TOKENS_HAIKU : MIN_CACHE_TOKENS_SONNET;
	my $tokens = $prompts[0] && $prompts[0][2] eq CACHE_ORDER->[0] ? TOOLS_PROMPT_TOKENS : 0;

	# count breakpoints set in prompts
	my $breakpoints = 0;
	foreach my $prompt (@prompts) {
		$breakpoints += exists $prompt->[1]{cache_control} && defined $prompt->[1]{cache_control}{type};
	}

	# up to 2 cache breakpoints in messages section
	my $cache_after_message = int($ctx->config->history_size / 2);

	my sub add_breakpoint ($prompt)
	{
		return !!1 if defined $prompt->[1]{cache_control}{type};
		return !!0 if $breakpoints == MAX_BREAKPOINTS;
		$breakpoints += 1;

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

			# message at cache checkpoint, and the prompt is big enough
			my $checkpoint_message = $message_number % $cache_after_message == 0 && $tokens > $cache_threshold;

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

