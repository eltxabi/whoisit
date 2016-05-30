-module(db_driver).

-export([conectar/0]).
-export([insertar/3]).
-export([actualizar_position/6]).
-export([find_followers/4]).
-export([find_senders/5]).
-export([del_user/3]).
-export([find_one/3]).

conectar() ->
	Host = "127.0.0.1",
	Port = 27017,
	Database = <<"test">>,
	mongo:connect (Host, Port, Database).

insertar(Connection, Collection, Data) ->	
	mongo:insert(Connection, Collection, Data).

actualizar_position(Connection, Collection, Erl_pid, Lat, Lng, Dist) ->
        Dlat = (Dist*6371)/110.574235,
        Dlng = (Dist*6371)/(110.574235 * math:cos(Lat)),
	Command = {<<"$set">>,{<<"loc">>,{<<"type">>,<<"Point">>,<<"coordinates">>,[Lng,Lat]},<<"dist">>,Dist,<<"square">>,{<<"type">>,<<"Polygon">>,<<"coordinates">>,[[[Lng-Dlng,Lat-Dlat],[Lng-Dlng,Lat+Dlat],[Lng+Dlng,Lat+Dlat],[Lng+Dlng,Lat-Dlat],[Lng-Dlng,Lat-Dlat]]]}}},
	mongo:update(Connection, Collection,{<<"erl_pid">>,Erl_pid}, Command, true).

find_senders(Connection, Collection, Lat, Lng, Dist) ->
	%Selector = {{<<"loc">> , '$near' , { '$geometry', { 'type', <<"Point">>, 'coordinates', [Lat, Lng] } , '$maxDistance', Dist} }},
	Selector = {<<"loc">> , {'$geoWithin' , { '$centerSphere', [[Lng, Lat], Dist]} }, <<"erl_pid">>,{'$ne',binary_to_list(term_to_binary(self()))}},
	Cursor = mongo:find(Connection, Collection, Selector, {<<"_id">>,false, <<"erl_pid">>, true,<<"loc">>,true,<<"dist">>,true}),
	Result = mc_cursor:rest(Cursor),
        %io:format("other :~w ~n",[Result]),
	mc_cursor:close(Cursor),
	%io:format("Selector :~w ~n",[Selector]),
	{ok , Result}.

find_followers(Connection, Collection, Lat, Lng) ->
	Selector = {<<"square">> , {'$geoIntersects' , {'$geometry', { 'type', <<"Point">>, 'coordinates', [Lng,Lat] }}},<<"erl_pid">>,{'$ne',binary_to_list(term_to_binary(self()))}},
        %lager:info("Selector followers :~s ~n ~n",[Selector]),
	Cursor = mongo:find(Connection, Collection, Selector, {<<"_id">>,false, <<"erl_pid">>, true,<<"loc">>,true,<<"dist">>,true}),
	Result = mc_cursor:rest(Cursor),
        %io:format("other :~w ~n",[Result]),
	mc_cursor:close(Cursor),
	%io:format("Selector :~w ~n",[Selector]),
	{ok , Result}.

del_user(Connection, Collection, Erl_pid) ->
        Selector = {<<"erl_pid">>,Erl_pid},
        mongo:delete_one(Connection, Collection, Selector).   	 
	
find_one(Connection, Collection, {}) ->
	mongo:find_one(Connection, Collection, {}).






