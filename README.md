#tor-router.sh
Transparent Tor router capable of serving a subnet.

Requirements (Debian, Ubuntu and variants):

```sudo apt-get install tor torsock redsocks geoip-bin geoip-database```

Edit /etc/redsocks.conf:
```
 redsocks {
  local_ip = 0.0.0.0;
  local_port = 12345;
  ip = 127.0.0.1;
  port = 9050;
 }```
 
To have your connection exit in a particular countr(yi|ies) add the following line to /etc/tor/torrc:
 
 ```ExitNodes {se},{br}```
 
Invocation: tor-router.sh [start|stop|start_router|stop_router]


Danja Vasiliev | http://k0a1a.net |  2015 | Artistic License 2.0
