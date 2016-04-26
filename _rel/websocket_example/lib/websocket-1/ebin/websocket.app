%% Feel free to use, reuse and abuse the code in this file.

{application, websocket, [
	{description, "Cowboy websocket example."},
	{vsn, "1"},
	{modules, ['mongo', 'mc_worker', 'mc_action_man', 'mc_cursor_sup', 'mc_cursor', 'mongo_app', 'mc_super_sup', 'db_driver', 'websocket_app', 'mochinum', 'mongo_protocol', 'mc_connection_man', 'bson', 'bson_binary', 'mongo_id_server', 'bson_tests', 'ws_handler', 'websocket_sup', 'ezwebframe_mochijson2', 'mc_worker_logic']},
	{registered, [websocket_sup]},
	{applications, [
		kernel,
		stdlib,
		cowboy,
		lager
	]},
	{mod, {websocket_app, []}},
	{env, []}
]}.
