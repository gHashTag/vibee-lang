-module(config_ffi).
-export([get_env/1]).

%% Get environment variable
get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, <<"Environment variable not set: ", Name/binary>>};
        Value -> {ok, list_to_binary(Value)}
    end.
