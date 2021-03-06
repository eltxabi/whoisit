-module(ws_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-import(ezwebframe_mochijson2, [encode/1, decode/1]).

-record(position, {lat,lng,dist}).
-record(state, {erl_pid,pos,followers}).
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
	   % <<"login">> ->
	    % Collection = <<"test">>,
	    % {ok, Connection} = db_driver:conectar(),
	    % db_driver:insertar(Connection, Collection,{user,Value}),
	    % New_State = #state{user=Value},
	    % {ok, Req, New_State};
            	
	    <<"message">> ->
	     foreach(fun(H) -> {_,Erl_pid,_,{_,_,_,[_,_]},_,_} = H, io:format("listtopid :~w ~n",[binary_to_term(list_to_binary(Erl_pid))]), binary_to_term(list_to_binary(Erl_pid)) ! {text , Msg, erl_pid, self(), pos, State#state.pos} end, State#state.followers),
	     {reply, {text, << Msg/binary >>}, Req, State};
	    <<"position">> ->
	     {struct,[{_,Lat},{_,Lng},{_,Dist}]}=Value,
	     Collection = <<"test">>,
	     {ok, Connection} = db_driver:conectar(),
             db_driver:actualizar_position(Connection, Collection, binary_to_list(term_to_binary(self())), Lat, Lng, Dist/6371),
             {ok,Senders_lst}=db_driver:find_senders(Connection, Collection, Lat, Lng, Dist/6371),
            Senders = case Senders_lst of
		[] -> [];
		_ -> list_to_binary(encode({array,json_senders(Senders_lst)}))
	    end,
            %aviso a los otros ue me envien sus mensjes
            foreach(fun(H) -> {_,Erl_pid,_,{_,_,_,[_,_]},_,_} = H,  binary_to_term(list_to_binary(Erl_pid)) ! {add_follower, H} end, Senders_lst),

            {ok,Followers_lst}=db_driver:find_followers(Connection, Collection, Lat, Lng),
		io:format("Followerslist :~w ~n",[Followers_lst]),
	     New_State = State#state{pos=#position{lat=Lat,lng=Lng,dist=Dist},followers=Followers_lst},	
             io:format("PID :~w ~n",[term_to_binary(self())]),
	     {reply,{text,Senders}, Req, New_State}	
	   end;
	Other ->
	   io:format("other :~s ~n",[Other])
    	end;
	
	%{reply, {text, << "That's what she said! ", Msg/binary >>}, Req, State};

websocket_handle(_Data, Req, State) ->
	{ok, Req, State}.

websocket_info({text, Msg, erl_pid, Erl_pid, pos, Position}, Req, State) ->
        %Comprobar si es para mi
        V= validate_distance(Position#position.lat,Position#position.lng,State#state.pos#position.lat,State#state.pos#position.lng,State#state.pos#position.dist),
        if V==true -> validate_message(Msg,Req, State);
          V==false -> validate_message(Erl_pid)
                  
        end;
 


websocket_info({add_follower, H}, Req, State) ->
        {_,_,_,{_,_,_,[Lat1,Lng1]},_,Dist} = H,
        V= validate_distance(Lat1,Lng1,State#state.pos#position.lat,State#state.pos#position.lng,Dist),
        New_State = if V==true -> State#state{followers=State#state.followers ++ [H]};
          V==false ->
               State   
        end, 
        {ok, Req,New_State};  

websocket_info({del_follower, Erl_pid}, Req, State) ->
        %eliminamos de la lista de followers
        lists:filter(fun(X) -> {_,Erl_pid,_,{_,_,_,[_,_]},_,_} = X end, State#state.followers),
        {ok, Req, State};
		
websocket_info(_Info, Req, State) ->
	io:format("mensajerecibidooooo :~n"),
	{ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
	ok.



validate_message(Erl_pid) ->
        binary_to_term(list_to_binary(Erl_pid)) ! {del_follower , self()}.

validate_message(Msg, Req, State) ->      
        io:format("mensajerecibido :~s,PID: ~w ~n",[Msg,self()]),
	{reply, {text, Msg}, Req, State}.


json_senders(List_Senders) ->
	parse_senders([],List_Senders).

parse_senders(Senders,[H|T]) ->
	{_,Erl_pid,_,{_,_,_,[Lat,Lng]},_,Dist} = H,
	Parse = {struct,[{erl_pid,Erl_pid},{loc,{struct,[{type,<<"Point">>},{coordinates,[Lat,Lng]}]}},{dist,Dist*6371}]},
	parse_senders([Parse|Senders],T);

parse_senders(Senders,[]) ->
	 Senders.

foreach(F, [H|T]) ->
    F(H),
    foreach(F, T);
foreach(_, []) ->
    ok.

validate_distance(Lat1,Lng1,Lat2,Lng2,Dist) ->
    Dist >= 6378.137 * math:acos(  math:cos( Lat1 ) *  math:cos( Lat2 ) *  math:cos( Lng2 - Lng1 ) +  math:sin( Lat1 ) *  math:sin( Lat2 ) ). 




