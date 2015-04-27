#tor-router.sh
transparent TOR-proxy capable of serving a subnet.

Danja Vasiliev | http://k0a1a.net |  2015 | Artistic License 2.0


requirements (debian):
tor, torsock, redsocks
/etc/redsocks.conf:
 redsocks {
  local_ip = 0.0.0.0;
  local_port = 12345;
  ip = 127.0.0.1;
  port = 9050;
 }

invocation: tor-router.sh [start|stop|start_router|stop_router]

