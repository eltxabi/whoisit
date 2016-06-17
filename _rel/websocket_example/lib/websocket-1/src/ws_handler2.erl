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
             lager:info("Mensje llegndo a : ~w   ~n ~n",[State#state.followers]),
             foreach(fun(H) -> {_,Erl_pid,_,{_,_,_,[_,_]},_,_} = H, lager:info("listtopid :~w ~n",[binary_to_term(list_to_binary(Erl_pid))]), binary_to_term(list_to_binary(Erl_pid)) ! {text , Msg, erl_pid, self(), pos, State#state.pos} end, State#state.followers),
	     %{reply, {text, << Msg/binary >>}, Req, State};
	     {ok, Req, State};

	    <<"position">> ->
	     {struct,[{_,Lat},{_,Lng},{_,Dist}]}=Value,
	     New_State = State#state{erl_pid=binary_to_list(term_to_binary(self())) ,pos=#position{lat=Lat,lng=Lng,dist=Dist}},
	     Collection = <<"test">>,
	     lager:info("Posicion recibida :~s ~s ~s ~n ~n",[Lat,Lng,Dist]),
	     lager:info("PID :~w ~n ~n",[term_to_binary(self())]),
	     {ok, Connection} = db_driver:conectar(),
             db_driver:actualizar_position(Connection, Collection, binary_to_list(term_to_binary(self())), Lat, Lng, Dist/6371),
             {ok,Senders_lst}=db_driver:find_senders(Connection, Collection, Lat, Lng, Dist/6371),
            Senders = case Senders_lst of
		[] -> [];
		_ -> list_to_binary(encode({struct,[{senders, {array,json_senders(Senders_lst)}}]}))
	    end,
            %aviso a los otros ue me envien sus mensjes
	    lager:info("Senders :~s ~n ~n",[Senders]),
	    Me = {<<"erl_pid">>,New_State#state.erl_pid,<<"loc">>,{<<"type">>,<<"Point">>,<<"coordinates">>,[New_State#state.pos#position.lat,New_State#state.pos#position.lng]},<<"dist">>,New_State#state.pos#position.dist},	
            lager:info("Me :~w ~n ~n",[Me]),
	    foreach(fun(H) -> {_,Erl_pid,_,{_,_,_,[_,_]},_,_} = H,  binary_to_term(list_to_binary(Erl_pid)) ! {add_follower, Me} end, Senders_lst),

            {ok,Followers_lst}=db_driver:find_followers(Connection, Collection, Lat, Lng),
		lager:info("Followerslist :~w ~n ~n",[Followers_lst]),
	     New_State2 = New_State#state{followers=Followers_lst},	
             {reply,{text,Senders}, Req, New_State2}	
	   end;
	Other ->
	   io:format("other :~s ~n",[Other])
    	end;
	
	%{reply, {text, << "That's what she said! ", Msg/binary >>}, Req, State};

websocket_handle(_Data, Req, State) ->
	{ok, Req, State}.

websocket_info({text, Msg, erl_pid, Erl_pid, pos, Position}, Req, State) ->
	lager:info("Recibido mensje: :~s ~n",[Msg]),
        %Comprobar si es para mi
        V= validate_distance(Position#position.lat,Position#position.lng,State#state.pos#position.lat,State#state.pos#position.lng,State#state.pos#position.dist/6371),
        if V==true -> lager:info("mensajerecibido :~s,PID: ~w ~n",[Msg,self()]),
	{reply, {text, Msg}, Req, State};
%validate_message(Msg,Req, State);
          V==false -> lager:info("Vamos a borrar PID: ~w ~n",[Erl_pid]),
       Erl_pid ! {del_follower , self()},
      {ok, Req, State}
%validate_message(Erl_pid)
                  
        end;
        %{ok, Req, State};


websocket_info({add_follower, H}, Req, State) ->
	%lager:info("add_follower PID: :~w ~n ~n",[term_to_binary(self())]),
	{_,Erl_pid,_,{_,_,_,[Lat1,Lng1]},_,Dist} = H,
        Condition = fun(E) -> {_,Erl_pid_foll,_,{_,_,_,[_,_]},_,_} = E, Erl_pid == Erl_pid_foll end,
	F = follower_included(State#state.followers, Condition),
        %lager:info("Valor de F:~w ~n ~n",[F]), 
	New_State = if F==false ->
	        V = validate_distance(Lat1,Lng1,State#state.pos#position.lat,State#state.pos#position.lng,Dist/6371),
		if V==true -> State#state{followers=State#state.followers ++ [H]};
		 V==false -> State 
		end;	
          F==true -> State   
        end, 
	lager:info("follower list of PID: :~w is: ~w ~n ~n",[term_to_binary(self()),New_State#state.followers]),
        {ok, Req,New_State}; 
 
	
    

websocket_info({del_follower, Erl_pid}, Req, State) ->
        %eliminamos de la lista de followers
        Del_pid = binary_to_list(term_to_binary(Erl_pid)),
        %lager:info("Eliminndo folowowers PID: ~w ~n ~n",[Del_pid]),
        New_followers = lists:filter(fun(X) -> {_,Del_pid2,_,{_,_,_,[_,_]},_,_} = X, Del_pid2==Del_pid end, State#state.followers),
        New_State = State#state{followers=New_followers},
        %lager:info("Elimindo list followers :~w ~n ~n", [Erl_pid]),
        {ok, Req, New_State};

%websocket_info({draw_sender , Erl_pid, Pos}, Req, State) ->
%        Sender=list_to_binary(encode({struct,[{senders, {array,[{struct,[{erl_pid,Erl_pid},{loc,{struct,[{type,<<"Point">>},{coordinates,[Pos#position.lat,Pos#position.lng]}]}},{dist,Pos#position.dist*6371}]}]}}]})),
%         lager:info("Sender add :~w ~n ~n", [Sender]),
%        {reply,{text,Sender}, Req, State};
		
websocket_info(_Info, Req, State) ->
	io:format("mensajerecibidooooo :~n"),
	{ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
        Collection = <<"test">>,
        {ok, Connection} = db_driver:conectar(),
	db_driver:del_user(Connection, Collection,binary_to_list(term_to_binary(self()))).
	



%validate_message(Erl_pid) ->
%       lager:info("Vamos a borrar PID: ~w ~n",[Erl_pid]),
%       Erl_pid ! {del_follower , self()}.

%validate_message(Msg, Req, State) ->      
%        lager:info("mensajerecibido :~s,PID: ~w ~n",[Msg,self()]),
%	{reply, {text, Msg}, Req, State}.


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
    lager:info("Lat1: ~w,Lng: ~w,Lat2: ~w,Lng2: ~w,   ~n",[Lat1,Lng1,Lat2,Lng2]),
    V 	         =   math:pi()/180,
   
    Diff_Lat 	 =   (Lat2 - Lat1)*V ,	
    Diff_Long	 =   (Lng2 - Lng1)*V,	
    NLat 		 =   Lat1*V,
    NLong 		 =   Lat2*V,
    A =   math:sin(Diff_Lat/2) * math:sin(Diff_Lat/2) + math:sin(Diff_Long/2) * math:sin(Diff_Long/2) * math:cos(NLat) * math:cos(NLong),
    D =  2 * math:asin(math:sqrt(A)),
    lager:info("validate distance D=~w , Dist=~w  ~n",[D,Dist]),
    Dist >= D. 

follower_included(L, Condition) ->
	%lager:info("Lista L: ~w ~n ~n",[L]),	
  case lists:dropwhile(fun(E) -> not Condition(E) end, L) of
    [] -> false;
    [_] -> true;
    [_|_] -> true
  end.


