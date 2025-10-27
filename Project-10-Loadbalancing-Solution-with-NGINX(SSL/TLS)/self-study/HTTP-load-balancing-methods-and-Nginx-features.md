# Nginx HTTP Load Balancing - Methods and Features

## What is Load Balancing?

Load balancing distributes incoming network traffic across multiple servers to ensure no single server becomes overwhelmed. This improves:
- **Performance:** Faster response times
- **Availability:** Service continues if one server fails
- **Scalability:** Easy to add more servers

---

## Nginx Load Balancing Methods

### 1. Round Robin (Default)
**How it works:** Requests are distributed evenly and sequentially across all servers.

**Configuration:**
```nginx
upstream backend {
    server web1.example.com;
    server web2.example.com;
    server web3.example.com;
}
```

**Pattern:**
```
Request 1 → Server 1
Request 2 → Server 2
Request 3 → Server 3
Request 4 → Server 1 (cycle repeats)
```

**Best for:**
- Servers with similar capabilities
- Stateless applications
- Simple, predictable distribution

---

### 2. Weighted Round Robin
**How it works:** Distributes requests based on server weights (capacity).

**Configuration:**
```nginx
upstream backend {
    server web1.example.com weight=3;
    server web2.example.com weight=2;
    server web3.example.com weight=1;
}
```

**Pattern:**
```
Out of 6 requests:
- Server 1 receives 3 requests (50%)
- Server 2 receives 2 requests (33%)
- Server 3 receives 1 request (17%)
```

**Best for:**
- Servers with different hardware specifications
- Gradually introducing new servers
- Phasing out old servers

---

### 3. Least Connections
**How it works:** Sends requests to the server with the fewest active connections.

**Configuration:**
```nginx
upstream backend {
    least_conn;
    server web1.example.com;
    server web2.example.com;
    server web3.example.com;
}
```

**Best for:**
- Applications with long-running connections
- Varying request processing times
- Database-heavy applications
- Dynamic workloads

---

### 4. IP Hash (Session Persistence)
**How it works:** Client IP address determines which server receives the request. Same client always goes to same server.

**Configuration:**
```nginx
upstream backend {
    ip_hash;
    server web1.example.com;
    server web2.example.com;
    server web3.example.com;
}
```

**Best for:**
- Applications requiring session persistence
- Shopping carts
- User authentication sessions
- Stateful applications

**Note:** Can cause uneven distribution if clients are behind NAT.

---

### 5. Generic Hash
**How it works:** Uses a custom key (URI, cookie, header) to determine server selection.

**Configuration:**
```nginx
upstream backend {
    hash $request_uri consistent;
    server web1.example.com;
    server web2.example.com;
    server web3.example.com;
}
```

**Examples:**
```nginx
# Hash based on URI
hash $request_uri consistent;

# Hash based on custom header
hash $http_x_custom_header consistent;

# Hash based on cookie
hash $cookie_sessionid consistent;
```

**Best for:**
- Content caching optimization
- Consistent routing for specific resources
- API rate limiting per endpoint

---

### 6. Least Time (Nginx Plus Only)
**How it works:** Sends requests to server with lowest average response time and fewest active connections.

**Configuration:**
```nginx
upstream backend {
    least_time header;  # or last_byte
    server web1.example.com;
    server web2.example.com;
}
```

**Best for:**
- Performance-critical applications
- Mixed server capabilities
- Optimizing user experience

**Note:** Requires Nginx Plus (commercial version).

---

## Advanced Load Balancing Features

### 1. Health Checks

#### Passive Health Checks (Free)
Nginx marks servers as failed after consecutive connection failures.

**Configuration:**
```nginx
upstream backend {
    server web1.example.com max_fails=3 fail_timeout=30s;
    server web2.example.com max_fails=3 fail_timeout=30s;
}
```

**Parameters:**
- `max_fails=3`: Mark unavailable after 3 failed attempts
- `fail_timeout=30s`: Try again after 30 seconds

#### Active Health Checks (Nginx Plus Only)
Proactively sends health check requests.

**Configuration:**
```nginx
upstream backend {
    server web1.example.com;
    server web2.example.com;
    health_check interval=5s fails=3 passes=2;
}
```

---

### 2. Server States

**Configuration:**
```nginx
upstream backend {
    server web1.example.com;                    # Active
    server web2.example.com weight=2;           # Active with weight
    server web3.example.com backup;             # Backup server
    server web4.example.com down;               # Temporarily disabled
    server web5.example.com max_conns=100;      # Connection limit
}
```

**States:**
- **Active:** Normal operation
- **Backup:** Only used when all primary servers fail
- **Down:** Permanently marked as unavailable (maintenance)
- **max_conns:** Limits concurrent connections

---

### 3. Keepalive Connections

Maintains persistent connections to backend servers for better performance.

**Configuration:**
```nginx
upstream backend {
    server web1.example.com;
    server web2.example.com;
    keepalive 32;  # Keep 32 connections open
}

server {
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

**Benefits:**
- Reduces latency
- Decreases CPU usage
- Improves throughput

---

### 4. Session Persistence (Sticky Sessions)

#### Cookie-based (Nginx Plus)
```nginx
upstream backend {
    server web1.example.com;
    server web2.example.com;
    sticky cookie srv_id expires=1h domain=.example.com path=/;
}
```

#### IP Hash (Free Alternative)
```nginx
upstream backend {
    ip_hash;
    server web1.example.com;
    server web2.example.com;
}
```

---

### 5. SSL/TLS Termination

Load balancer handles SSL, communicates with backends over HTTP.

**Configuration:**
```nginx
upstream backend {
    server web1.example.com;
    server web2.example.com;
}

server {
    listen 443 ssl;
    server_name example.com;
    
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/key.pem;
    
    location / {
        proxy_pass http://backend;  # HTTP to backend
    }
}
```

**Benefits:**
- Centralized SSL certificate management
- Reduces backend server load
- Easier certificate renewal

---

### 6. Request Buffering

**Configuration:**
```nginx
upstream backend {
    server web1.example.com;
    server web2.example.com;
}

server {
    location / {
        proxy_pass http://backend;
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
}
```

**Benefits:**
- Frees up backend connections faster
- Handles slow clients better
- Improves overall throughput

---

### 7. Load Balancing with Proxy Headers

Essential headers for proper load balancing:

**Configuration:**
```nginx
location / {
    proxy_pass http://backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
}
```

**Why these matter:**
- Backend servers know the original client IP
- Applications can distinguish between HTTP/HTTPS
- Logging shows real client information
- Security policies work correctly

---

## Complete Example: Production-Ready Configuration

```nginx
upstream backend {
    least_conn;  # Use least connections method
    
    server web1.example.com:80 weight=3 max_fails=3 fail_timeout=30s;
    server web2.example.com:80 weight=2 max_fails=3 fail_timeout=30s;
    server web3.example.com:80 backup;
    
    keepalive 32;
}

server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$server_name$request_uri;  # Redirect to HTTPS
}

server {
    listen 443 ssl http2;
    server_name example.com www.example.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    # Load Balancing
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

---

## Comparison Table

| Method | Use Case | Session Persistence | Complexity |
|--------|----------|---------------------|------------|
| Round Robin | General purpose, stateless | No | Low |
| Weighted RR | Different server sizes | No | Low |
| Least Connections | Variable request times | No | Medium |
| IP Hash | Session-based apps | Yes | Medium |
| Generic Hash | Cache optimization | Configurable | High |
| Least Time | Performance critical | No | High |

---

## Best Practices

1. ✅ **Start with Round Robin** - Simple and effective for most cases
2. ✅ **Use Weighted** when servers have different capacities
3. ✅ **Enable health checks** - Prevent sending traffic to failed servers
4. ✅ **Configure keepalive** - Improves performance significantly
5. ✅ **Set proper timeouts** - Prevent hanging connections
6. ✅ **Use backup servers** - Ensure high availability
7. ✅ **Monitor logs** - Track which servers handle requests
8. ✅ **Test failover** - Verify backup servers work correctly
9. ✅ **Use SSL termination** - Simplifies certificate management
10. ✅ **Set appropriate headers** - Ensure backends see real client info

---

## Monitoring and Troubleshooting

### Check Active Connections
```bash
# View Nginx status (requires stub_status module)
curl http://localhost/nginx_status
```

### Test Load Distribution
```bash
# Make multiple requests and check which server responds
for i in {1..10}; do
    curl -I http://example.com
done
```

### View Access Logs
```bash
# Monitor requests in real-time
sudo tail -f /var/log/nginx/access.log

# Count requests per backend (if logging upstream)
sudo grep "upstream" /var/log/nginx/access.log | sort | uniq -c
```

---

## Summary

Nginx provides powerful and flexible load balancing with:
- **Multiple algorithms** for different use cases
- **Health monitoring** to ensure reliability
- **Session persistence** for stateful applications
- **SSL termination** for simplified certificate management
- **Advanced features** for production environments

For most projects, **Round Robin with health checks** is a great starting point. Adjust the method based on your specific requirements and application behavior.
