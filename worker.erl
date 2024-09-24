-module(worker).
-export([start/5, stop/1, peers/2]).

start(Name, Logger, Seed, Sleep, Jitter) ->
    spawn_link(fun() -> init(Name, Logger, Seed, Sleep, Jitter) end).

stop(Worker) ->
    Worker ! stop.

init(Name, Log, Seed, Sleep, Jitter) ->
    rand:seed(exsplus, {Seed, Seed + 1, Seed + 2}),
    % Initialize the Lamport clock
    Clock = time:zero(),  
    receive
        {peers, Peers} ->
            % Pass the initialized clock into the loop function
            loop(Name, Log, Peers, Sleep, Jitter, Clock);
        stop -> 
            ok
    end.

peers(Wrk, Peers) ->
   Wrk ! {peers, Peers}.

loop(Name, Log, Peers, Sleep, Jitter, Clock)->
    Wait = rand:uniform(Sleep),
    receive
        {msg, ReceivedTime, Msg} ->
        % Update the clock with the received timestamp before incrementing
        NewClock = time:inc(Name, time:merge(Clock, ReceivedTime)),
        Log ! {log, Name, NewClock, {received, Msg}},
        loop(Name, Log, Peers, Sleep, Jitter, NewClock);
        stop -> 
            ok;
        Error ->
            Log ! {log, Name, time, {error, Error}}
    after Wait ->
            Selected = select(Peers),
            UpdatedClock = na,
            Message = {hello, rand:uniform(100)},
            Selected ! {msg, UpdatedClock, Message},
            jitter(Jitter),
            Log ! {log, Name, UpdatedClock, {sending, Message}},
            loop(Name, Log, Peers, Sleep, Jitter, UpdatedClock)
    end.

select(Peers) ->
    lists:nth(rand:uniform(length(Peers)), Peers).
    
jitter(0) -> ok;
jitter(Jitter) -> timer:sleep(rand:uniform(Jitter)).
