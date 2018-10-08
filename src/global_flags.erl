%% @doc Write once global flags for Erlang and Elixir.
%%
%% This module provides a very simple API for managing global
%% flags and conditional execution based on those flags. This
%% is designed for setups where you need quick flag checks
%% before execution, but don't want to waste a process, start
%% an ETS table, and cannot rely on the process dictionary.
%%
%% It works by using a super simple atom table check, which
%% makes the check almost instant (and without having to rely
%% on any prior state).
%%
%% Flags cannot be unset after being set, due to the inability
%% to purge from the atom table. If you want such ability, you
%% likely want to deal with ETS or some other storage.
-module(global_flags).

%% Public API
-export([is_set/1, once/2, set/1, with/2, without/2]).

%% ===================================================================
%% Public API
%% ===================================================================

%% @doc Checks if a global flag is set.
-spec is_set(binary() | list()) -> boolean().
is_set(Flag) when is_binary(Flag); is_list(Flag) ->
    try list_to_existing_atom(to_flag(Flag)) of
        _ -> true
    catch
        _:_ -> false
    end.

%% @doc Runs a function a single time, based on the provided flag.
-spec once(binary() | list(), fun(() -> any())) -> ok.
once(Flag, Fun) when
    is_binary(Flag); is_list(Flag),
    is_function(Fun, 0)
->
    case is_set(Flag) of
        true -> ok;
        false -> Fun(), set(Flag)
    end.

%% @doc Sets a global flag, typically only used internally.
-spec set(binary() | list()) -> ok.
set(Flag) when is_binary(Flag); is_list(Flag) ->
    _ = list_to_atom(to_flag(Flag)),
    ok.

%% @doc Runs a function only if the provided flag is set.
-spec with(binary() | list(), fun(() -> any())) -> ok.
with(Flag, Fun) when
    is_binary(Flag); is_list(Flag),
    is_function(Fun, 0)
->
    case is_set(Flag) of
        false   -> ok;
        true    -> Fun(), ok
    end.

%% @doc Runs a function only if the provided flag is not set.
-spec without(binary() | list(), fun(() -> any())) -> ok.
without(Flag, Fun) when
    is_binary(Flag); is_list(Flag),
    is_function(Fun, 0)
->
    case is_set(Flag) of
        true    -> ok;
        false   -> Fun(), ok
    end.

%% ===================================================================
%% Private API
%% ===================================================================

to_flag(Flag) when is_list(Flag) ->
    string:concat("flag:", Flag);
to_flag(Flag) when is_binary(Flag) ->
    to_flag(binary_to_list(Flag)).

%% ===================================================================
%% Private test cases
%% ===================================================================

-ifdef(TEST).
    -include_lib("eunit/include/eunit.hrl").

    set_test() ->
        Flag = "test_set",
        ?assertNot(global_flags:is_set(Flag)),
        ?assert(global_flags:set(Flag) =:= ok),
        ?assert(global_flags:is_set(Flag)),
        ok.

    once_test() ->
        Flag = "test_once",
        global_flags:once(Flag, fun() ->
            ok
        end),
        global_flags:once(Flag, fun() ->
            error("should not receive second call")
        end).

    with_test() ->
        Flag = "test_with",
        global_flags:with(Flag, fun() ->
            error("should not run due to being unset")
        end),
        global_flags:set(Flag),
        global_flags:with(Flag, fun() ->
            self() ! 1
        end),
        receive
            1 -> ok
        after
            100 -> error("should have received a message")
        end.

    without_test() ->
        Flag = "test_without",
        global_flags:without(Flag, fun() ->
            self() ! 1
        end),
        receive
            1 -> ok
        after
            100 -> error("should have received a message")
        end,
        global_flags:set(Flag),
        global_flags:without(Flag, fun() ->
            error("should not run due to being set")
        end).
-endif.
