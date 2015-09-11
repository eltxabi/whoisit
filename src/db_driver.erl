-module(db_driver).

-export([conectar/0]).
-export([insertar/3]).
-export([actualizar_position/6]).
-export([find_senders/5]).
-export([find_one/3]).

conectar() ->
	Host = "127.0.0.1",
	Port = 27017,
	Database = <<"test">>,
	mongo:connect (Host, Port, Database).

insertar(Connection, Collection, Data) ->	
	mongo:insert(Connection, Collection, Data).

actualizar_position(Connection, Collection, User, Lat, Lng, Dist) ->
	Command = {<<"$set">>,{<<"loc">>,{<<"type">>,<<"Point">>,<<"coordinates">>,[Lng,Lat]},<<"dist">>,Dist,<<"square">>,{<<"type">>,<<"Polygon">>,<<"coordinates">>,[[Lat-Dist,Lng-Dist],[Lat+Dist,Lng+Dist],[Lat-Dist,Lng+Dist],[Lat+Dist,Lng-Dist]]}}},
	mongo:update(Connection, Collection,{<<"user">>, User}, Command).

find_senders(Connection, Collection, Lat, Lng, Dist) ->
	%Selector = {{<<"loc">> , '$near' , { '$geometry', { 'type', <<"Point">>, 'coordinates', [Lat, Lng] } , '$maxDistance', Dist} }},
	Selector = {<<"loc">> , {'$geoWithin' , { '$centerSphere', [[Lng, Lat], Dist]} }},
	Cursor = mongo:find(Connection, Collection, Selector, {<<"_id">>,false, <<"user">>, true,<<"loc">>,true,<<"dist">>,true}),
	Result = mc_cursor:rest(Cursor),
        io:format("other :~w ~n",[Result]),
	mc_cursor:close(Cursor),
	io:format("Selector :~w ~n",[Selector]),
	{ok , Result}.
	
find_one(Connection, Collection, {}) ->
	mongo:find_one(Connection, Collection, {}).






