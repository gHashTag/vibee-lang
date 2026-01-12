-module(twitter_ffi).
-export([hmac_sha1/2, get_timestamp/0, generate_nonce/0, percent_encode/1]).

%% HMAC-SHA1 signing
hmac_sha1(Key, Message) ->
    KeyBin = unicode:characters_to_binary(Key),
    MessageBin = unicode:characters_to_binary(Message),
    Mac = crypto:mac(hmac, sha, KeyBin, MessageBin),
    base64:encode(Mac).

%% Get current Unix timestamp
get_timestamp() ->
    integer_to_list(erlang:system_time(second)).

%% Generate random nonce
generate_nonce() ->
    Bytes = crypto:strong_rand_bytes(16),
    base64:encode(Bytes).

%% Percent encode according to RFC 3986
percent_encode(String) ->
    StringBin = unicode:characters_to_binary(String),
    percent_encode_binary(StringBin, <<>>).

percent_encode_binary(<<>>, Acc) ->
    binary_to_list(Acc);
percent_encode_binary(<<C, Rest/binary>>, Acc) when
    (C >= $A andalso C =< $Z) orelse
    (C >= $a andalso C =< $z) orelse
    (C >= $0 andalso C =< $9) orelse
    C =:= $- orelse C =:= $_ orelse C =:= $. orelse C =:= $~ ->
    percent_encode_binary(Rest, <<Acc/binary, C>>);
percent_encode_binary(<<C, Rest/binary>>, Acc) ->
    Hex = integer_to_list(C, 16),
    Encoded = list_to_binary([$%, Hex]),
    percent_encode_binary(Rest, <<Acc/binary, Encoded/binary>>).
