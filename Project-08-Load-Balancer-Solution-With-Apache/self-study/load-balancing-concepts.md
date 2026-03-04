# Load Balancing Concepts

## Introduction
Load balancing is the process of distributing incoming network traffic across multiple servers to ensure no single server becomes overwhelmed. It improves performance, availability, and reliability of applications. Load balancers act as a reverse proxy, sitting between clients and backend servers.

## Load Balancing Concepts
Key ideas in load balancing include:

- **High availability**: Applications remain accessible even if one server fails.
- **Scalability**: More servers can be added to handle increased demand.
- **Fault tolerance**: Requests are automatically rerouted if a server becomes unhealthy.
- **Health checks**: Load balancers continuously monitor backend server status.
- **Session persistence ("sticky sessions")**: Ensuring a user’s requests are always sent to the same backend server when required.

### Common Load Balancing Algorithms
- **Round Robin**: Each request is distributed sequentially to servers.
- **Least Connections**: Requests are sent to the server with the fewest active connections.
- **IP Hash**: Requests from the same client IP are sent to the same server.
- **Weighted Round Robin/Least Connections**: Servers with higher capacity are given more requests.
- **Random**: Requests are distributed randomly.

## Options for Setting Up Load Balancing
- **Hardware Load Balancers**: Physical appliances placed in data centers. Used traditionally but expensive and less flexible.
- **Software Load Balancers**: Installed and configured on servers (e.g., HAProxy, Nginx, Envoy).
- **Cloud Load Balancers**: Fully managed by cloud providers such as AWS, Azure, or GCP. Examples:
  - AWS Elastic Load Balancing (ELB)
  - Google Cloud Load Balancer
  - Azure Load Balancer / Application Gateway
- **DNS Load Balancing**: Using DNS to distribute requests across multiple servers (less dynamic but simple).

## Layer 4 vs Layer 7 Load Balancers

### Layer 4 (Transport Layer / Network Load Balancer)
- Operates at the **transport layer** (TCP/UDP).
- Routes traffic based only on IP address and port.
- Very fast and efficient, low latency.
- Limited flexibility because it cannot inspect packet content.
- Example use case: Distributing TCP traffic for a database cluster.
- **AWS Example**: Network Load Balancer (NLB).

### Layer 7 (Application Layer Load Balancer)
- Operates at the **application layer** (HTTP/HTTPS).
- Makes routing decisions based on request content (headers, URLs, cookies).
- Supports advanced features like SSL termination, host/path-based routing, and WebSockets.
- Higher latency compared to L4 but more intelligent.
- Example use case: Routing traffic between different microservices based on URL path.
- **AWS Example**: Application Load Balancer (ALB).

### Comparison Table

| Feature           | Layer 4 (Network LB)        | Layer 7 (Application LB)         |
|-------------------|-----------------------------|----------------------------------|
| OSI Layer         | Transport (TCP/UDP)         | Application (HTTP/HTTPS)         |
| Routing Decision  | Based on IP and Port        | Based on content (headers, URL, cookies) |
| Performance       | Very fast, low latency      | Slightly slower, more overhead   |
| Flexibility       | Limited                     | Very flexible                    |
| Common Use Cases  | Database traffic, gaming, VoIP | Web apps, APIs, microservices   |
| AWS Example       | Network Load Balancer (NLB) | Application Load Balancer (ALB)  |

## Benefits of Load Balancing
- Improved application availability and reliability
- Optimized resource utilization
- Fault tolerance and failover capabilities
- Scalability to handle growing traffic
- Better user experience with reduced response times
- Centralized SSL/TLS management (especially with L7)
- Protection against server overload

## AWS Load Balancing Options
- **Application Load Balancer (ALB)** – Layer 7, for HTTP/HTTPS traffic and content-based routing.
- **Network Load Balancer (NLB)** – Layer 4, for TCP/UDP traffic with ultra-low latency.
- **Classic Load Balancer (CLB)** – Legacy option, supports both L4 and L7 but less feature-rich.
- **Gateway Load Balancer (GLB)** – For integrating third-party virtual appliances (firewalls, intrusion detection).

## Conclusion
Load balancing ensures that modern applications remain highly available, scalable, and resilient. Choosing between Layer 4 and Layer 7 depends on performance requirements and routing needs. In the cloud, managed services like AWS Elastic Load Balancing provide flexible and reliable options without the complexity of managing hardware.
