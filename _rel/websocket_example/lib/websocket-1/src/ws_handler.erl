-module(ws_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-import(ezwebframe_mochijson2, [encode/1, decode/1]).

-record(position, {lat,lng,dist}).
-record(state, {user,pos,followers}).
%-record(struct, {lst=[]}).

init({tcp, http}, _Req, _Opts) ->
	%application:start (bson),
	%application:start (mongodb),
	{upgrade, protocol, cowboy_websocket}.

websocket_init(_TransportName, Req, _Opts) ->
	%erlang:start_timer(1000, self(), <<"Hello!">>),
	State = #state{},
	{ok, Req, State}.

websocket_handle({text, Msg}, Req, State) ->
	case catch decode(Msg) of
	{'EXIT', _Why} ->
	   io:format("exit : ~n"); 
	{struct, Data} ->
	   [{Key,Value}|_] = Data, 
	   case Key of
	    <<"login">> ->
	     %User = proplists:get_value(<<"login">>, Data),
	     Collection = <<"test">>,
	     {ok, Connection} = db_driver:conectar(),
	     db_driver:insertar(Connection, Collection,{user,Value}),
	     New_State = #state{user=Value},
	     {ok, Req, New_State};	
	    <<"message">> ->
	     {reply, {text, << Msg/binary >>}, Req, State};
	    <<"position">> ->
	     {struct,[{_,Lat},{_,Lng},{_,Dist}]}=Value,
	     Collection = <<"test">>,
	     {ok, Connection} = db_driver:conectar(),
	     db_driver:actualizar_position(Connection, Collection,State#state.user, Lat, Lng, Dist/6371),
	     {ok,Send_lst}=db_driver:find_senders(Connection, Collection, Lat, Lng, Dist/6371),
	    Send = list_to_binary(encode({array,json_followers(Send_lst)})),
	     New_State = State#state{pos=#position{lat=Lat,lng=Lng,dist=Dist}},	
	     {reply,{text,Send}, Req, New_State}	
	   end;
	Other ->
	   io:format("other :~s ~n",[Other])
    	end;
	
	%{reply, {text, << "That's what she said! ", Msg/binary >>}, Req, State};

websocket_handle(_Data, Req, State) ->
	{ok, Req, State}.

websocket_info({timeout, _Ref, Msg}, Req, State) ->
	%Host = "127.0.0.1",
	%Port = 27017,
	%Database = <<"test">>,
	Collection = <<"test">>,
	%{ok, Connection} = mongo:connect (Host, Port, Database),
	{ok, Connection} = db_driver:conectar(),
	%mongo:insert(Connection, Collection, [{erl_pid,pid_to_list(self())}]),
	db_driver:insertar(Connection, Collection, [{erl_pid,pid_to_list(self())}]),
	S=db_driver:find_one(Connection, Collection, {}),
	io:format("SERVER ~w: ~n", [self()]),
	%io:format(Host),
	%io:format(integer_to_list(Port)),
	%io:format(Database),
	%io:format(pid_to_list(Connection)),	
	io:format(lists:flatten(io_lib:format("~p ~n",[S]))),
	%io:format(binary_to_list(bson:put_document(S))),
	%erlang:start_timer(1000, self(), <<"How' you doin'?">>),
	{reply, {text, Msg}, Req, State};
	
websocket_info(_Info, Req, State) ->
	{ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
	ok.

json_followers(List_Followers) ->
	parse_followers([],List_Followers).

parse_followers(Followers,[H|T]) ->
	{_,User,_,{_,_,_,[Lat,Lng]},_,Dist} = H,
	Parse = {struct,[{user,User},{loc,{struct,[{type,<<"Point">>},{coordinates,[Lat,Lng]}]}},{dist,Dist*6371}]},
	parse_followers([Parse|Followers],T);

parse_followers(Followers,[]) ->
	 Followers.





