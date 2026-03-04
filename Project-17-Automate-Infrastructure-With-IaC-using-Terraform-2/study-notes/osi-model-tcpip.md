# OSI Model, TCP/IP Suite, and How They Connect to the Internet

## The Problem These Models Solve

When two computers need to communicate, an enormous amount of work happens behind the scenes breaking data into packets, addressing those packets, routing them across networks, ensuring they arrive correctly, and reassembling them at the destination. Before any of this was standardised, different vendors built proprietary systems that could not talk to each other.

The OSI model and TCP/IP suite are both attempts to bring order to this complexity by defining layers of responsibility. Each layer handles a specific job and communicates only with the layers directly above and below it.

---

## The OSI Model

OSI stands for Open Systems Interconnection. It was developed by the International Organisation for Standardisation (ISO) as a conceptual framework a way to understand and discuss how network communication works. It has 7 layers.

You do not need to memorise them. What matters is the idea: each layer adds a specific capability to the communication process, and when something breaks, understanding which layer is responsible helps you find the problem faster.

```
Layer 7 — Application
Layer 6 — Presentation
Layer 5 — Session
Layer 4 — Transport
Layer 3 — Network
Layer 2 — Data Link
Layer 1 — Physical
```

Working from the bottom up:

**Layer 1 — Physical**
The actual hardware: cables, fibre optic lines, radio signals, electrical pulses. This layer deals with raw bits — 1s and 0s transmitted as physical signals. It has no understanding of what those bits mean.

**Layer 2 — Data Link**
Takes raw bits from Layer 1 and organises them into frames. Introduces MAC addresses — hardware identifiers burned into network interface cards. This is how devices on the same local network identify each other. Switches operate at this layer.

**Layer 3 — Network**
Introduces IP addresses and handles routing between different networks. This is where packets are created, addressed with source and destination IPs, and routed toward their destination. Routers operate here. Your AWS route tables make Layer 3 routing decisions.

**Layer 4 — Transport**
Responsible for end-to-end communication between applications. The two main protocols here are:
- **TCP (Transmission Control Protocol):** Reliable, ordered, error-checked delivery. If a packet is lost, TCP retransmits it. Used when accuracy matters — web traffic, database queries, file transfers.
- **UDP (User Datagram Protocol):** Faster, no guarantee of delivery or order. Used when speed matters more than perfection — video streaming, DNS lookups, gaming.

Port numbers also live at this layer. Port 443 is HTTPS, port 22 is SSH, port 3306 is MySQL. When security groups open port 443, that is a Layer 4 decision.

**Layer 5 — Session**
Manages the establishment, maintenance, and termination of sessions between applications. It keeps track of which communication belongs to which ongoing conversation. This is what allows you to have multiple browser tabs open to the same server simultaneously.

**Layer 6 — Presentation**
Handles data formatting, translation, encryption, and compression. TLS/SSL encryption operates here — this is the layer responsible for scrambling HTTPS traffic so it cannot be read in transit.

**Layer 7 — Application**
The layer closest to the user. HTTP, HTTPS, DNS, FTP, SSH — these are all application layer protocols. When a browser sends a GET request, that is a Layer 7 operation. Application Load Balancers in AWS operate at Layer 7 — they can inspect HTTP request content (host headers, URL paths) to make intelligent routing decisions.

---

## The TCP/IP Suite

TCP/IP is the actual protocol stack the internet runs on. Unlike the OSI model (designed as a theoretical reference), TCP/IP was built pragmatically to solve real problems. It predates OSI and is what everything in practice actually uses.

TCP/IP has 4 layers:

```
Application Layer
Transport Layer
Internet Layer
Network Access Layer
```

**Application Layer** covers what OSI calls Layers 5, 6, and 7. HTTP, HTTPS, DNS, SSH, FTP all live here.

**Transport Layer** maps to OSI Layer 4. TCP and UDP live here. This layer handles segmentation of data and end-to-end delivery.

**Internet Layer** maps to OSI Layer 3. The IP protocol lives here. It handles addressing and routing of packets across networks.

**Network Access Layer** maps to OSI Layers 1 and 2. It handles physical transmission and local network framing (Ethernet, Wi-Fi, etc.).

---

## How OSI and TCP/IP Relate

OSI is the conceptual model — it is how you reason about network communication in a structured way. TCP/IP is the implementation — it is what actually runs.

```
OSI Model               TCP/IP Suite
──────────────────      ──────────────────────
Layer 7  Application ┐
Layer 6  Presentation├─ Application Layer
Layer 5  Session     ┘
Layer 4  Transport   ──  Transport Layer
Layer 3  Network     ──  Internet Layer
Layer 2  Data Link   ┐
Layer 1  Physical    ┘─  Network Access Layer
```

When engineers say "Layer 7 load balancer," they mean one that operates at the Application layer — it understands HTTP and can route based on URL paths or host headers. When they say "Layer 4," they mean one that routes based only on IP and port, with no inspection of content.

AWS Application Load Balancers are Layer 7. AWS Network Load Balancers are Layer 4.

---

## How This Connects to End-to-End Web Solutions

When a user types a URL and hits Enter, here is what actually happens across the layers:

1. **DNS lookup (Layer 7 — Application):** The browser queries a DNS server to convert the domain name into an IP address.

2. **TCP handshake (Layer 4 — Transport):** The browser and server perform a three-way handshake (SYN → SYN-ACK → ACK) to establish a reliable connection on port 443.

3. **TLS negotiation (Layer 6 — Presentation):** The client and server agree on encryption and exchange keys. From this point the traffic is encrypted.

4. **HTTP request sent (Layer 7 — Application):** The browser sends an HTTP GET request over the encrypted connection.

5. **IP routing (Layer 3 — Network):** The packet travels across multiple routers on the internet. Each router reads the destination IP and forwards the packet toward its target. Your AWS route tables participate in this when the packet reaches your VPC.

6. **Security group evaluation (Layer 4 — Transport):** When the packet reaches AWS, the security group checks whether port 443 is allowed. If not, the packet is dropped before it reaches anything.

7. **Load balancer routing (Layer 7 — Application):** The External ALB receives the request, inspects the host header or URL path, and forwards it to the appropriate target group.

8. **Application processing:** Nginx, the web application, and the database handle the request at the application level and build a response.

9. **Response travels back:** The entire journey happens in reverse — the response is encrypted, packetised, routed across the internet, and reassembled at the browser.

---

## The Practical Takeaway

You do not need to recite all seven OSI layers in order. What matters day-to-day in infrastructure work is understanding which layer is relevant to which tool:

- **Layer 3** — IP addressing and routing. Your VPC design, subnets, and route tables live here.
- **Layer 4** — Ports and transport protocols. Your security group rules are Layer 4 decisions.
- **Layer 7** — HTTP and application logic. Your ALB, Nginx reverse proxy, and URL-based routing live here.

When something breaks, walking through the layers from bottom to top is one of the most reliable debugging strategies. Start with: is the route there? Is the port open? Is the application responding? That progression follows the OSI model exactly.
