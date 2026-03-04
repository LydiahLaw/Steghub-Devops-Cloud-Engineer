# Apache mod_proxy_balancer Configuration Notes

## Overview
The `mod_proxy_balancer` module is Apache's built-in load balancing solution that distributes incoming requests across multiple backend servers.

---

## Key Configuration Aspects

### 1. Load Balancing Methods
Apache supports several algorithms for distributing traffic:

- **byrequests** - Distributes requests evenly based on request count
- **bytraffic** - Distributes based on amount of traffic (bytes transferred)
- **bybusyness** - Sends requests to the server with fewest active connections
- **heartbeat** - Uses heartbeat signals to determine server health

Example:
```apache
ProxySet lbmethod=bytraffic
```

### 2. BalancerMember Configuration
Each backend server can have specific parameters:

- **loadfactor** - Weight for load distribution (default: 1)
- **timeout** - Connection timeout in seconds
- **retry** - Time to wait before retrying a failed server
- **route** - Used for sticky sessions

Example:
```apache
BalancerMember http://192.168.1.10:80 loadfactor=5 timeout=10 retry=60
```

### 3. Health Checks
Monitor backend server availability:

- **ping** - Send periodic health check requests
- **timeout** - Mark server as down if it doesn't respond
- **status** - View balancer status at `/balancer-manager`

---

## Sticky Sessions

### What Are Sticky Sessions?
**Sticky sessions** (also called session persistence or session affinity) ensure that a user's requests are always sent to the same backend server during their session.

### How It Works
1. User makes initial request
2. Load balancer assigns them to a specific backend server
3. All subsequent requests from that user go to the same server
4. Session data remains consistent

### When to Use Sticky Sessions

**Use sticky sessions when:**
- Application stores session data locally on the server (not in shared storage)
- Shopping carts or user login sessions are stored in server memory
- Application state is not shared across servers
- Using file-based sessions without a shared filesystem

**Avoid sticky sessions when:**
- Using centralized session storage (Redis, Memcached, database)
- Application is fully stateless
- You need true load distribution for performance
- High availability is critical (server failure loses all sessions)

### Configuring Sticky Sessions

```apache
<Proxy "balancer://mycluster">
    BalancerMember http://192.168.1.10:80 route=server1
    BalancerMember http://192.168.1.11:80 route=server2
    ProxySet stickysession=ROUTEID
</Proxy>

ProxyPass / balancer://mycluster/ stickysession=ROUTEID
ProxyPassReverse / balancer://mycluster/
```

The application must set a cookie or URL parameter called `ROUTEID` that contains the route value.

---

## Best Practices

1. **Monitor Performance** - Enable `balancer-manager` for real-time monitoring
2. **Set Appropriate Timeouts** - Prevent hanging connections
3. **Use Health Checks** - Automatically remove failed servers
4. **Consider Session Storage** - Use shared storage instead of sticky sessions when possible
5. **Load Factor Tuning** - Adjust based on server capacity
6. **Failover Strategy** - Plan for backend server failures

---

## Additional Resources

- [Apache mod_proxy_balancer Documentation](https://httpd.apache.org/docs/current/mod/mod_proxy_balancer.html)
- [Apache Load Balancing Guide](https://httpd.apache.org/docs/current/howto/reverse_proxy.html)
