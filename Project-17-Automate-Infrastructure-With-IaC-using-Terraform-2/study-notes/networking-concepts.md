# Networking Concepts

## IP Addresses

Every device that connects to a network needs an identifier — that identifier is an IP address. Think of it the way you think of a postal address: without one, there is no way to know where to send data or where it came from.

The version most infrastructure still runs on is IPv4. An IPv4 address is a 32-bit number written as four groups of digits separated by dots for example `192.168.1.10`. Each group (called an octet) can be any value from 0 to 255. That gives roughly 4.3 billion possible addresses, which sounds like a lot until you consider there are more internet-connected devices than that today. This is part of why IPv6 was introduced, using 128-bit addresses, though IPv4 remains dominant in most cloud infrastructure including AWS.

IP addresses come in two scopes:

**Public IP addresses** are globally routable any device on the internet can send traffic to them. When you access a website, your request reaches a server at its public IP.

**Private IP addresses** exist only within a local network and are not directly reachable from the internet. AWS uses private IPs inside VPCs. The reserved private ranges are:
- `10.0.0.0 – 10.255.255.255`
- `172.16.0.0 – 172.31.255.255`
- `192.168.0.0 – 192.168.255.255`

When you create a VPC in AWS and assign it a CIDR like `172.16.0.0/16`, every resource inside it gets a private IP from that range.

---

## Subnets

A subnet (short for subnetwork) is a logical division of a larger IP network into smaller segments. You do this for two main reasons: security and traffic control.

In AWS, a VPC is your private network. Subnets are how you divide it. The most important distinction is between public and private subnets:

**Public subnets** have a route to an Internet Gateway, which means resources placed in them (with a public IP) can communicate directly with the internet. Load balancers and bastion hosts typically live here.

**Private subnets** have no direct route to the internet. Resources here like application servers, databases, and file systems — are isolated from inbound internet traffic. They can still reach the internet for outbound requests (like downloading updates) through a NAT Gateway, but nothing from the internet can initiate a connection to them.

This separation is a core security principle. Even if an attacker compromised your load balancer, they still cannot directly reach your database because it sits in a private subnet with no inbound path from the internet.

In the Project 17 architecture, the layout is:
- Public subnets → External ALB, Bastion, NAT Gateway
- Private subnets 0 & 1 → Webservers (WordPress, Tooling, Nginx ASG)
- Private subnets 2 & 3 → Data layer (RDS, EFS)

---

## CIDR Notation

CIDR stands for Classless Inter-Domain Routing. It is a compact way of expressing both an IP address and the size of the network it belongs to.

The format is: `IP address / prefix length` — for example `172.16.0.0/16`.

The prefix length (the number after the slash) tells you how many bits of the address are fixed as the network portion. The remaining bits are available for individual host addresses within that network.

Some examples using `172.16.0.0` as the base:

| CIDR | Fixed bits | Usable hosts | Example use |
|------|-----------|--------------|-------------|
| /16 | 16 | ~65,534 | Entire VPC |
| /20 | 20 | ~4,094 | Large subnet |
| /24 | 24 | 254 | Small subnet |
| /32 | 32 | 1 | Single specific IP |

When Terraform's `cidrsubnet()` function is used like `cidrsubnet("172.16.0.0/16", 4, 0)`, it takes the VPC CIDR, extends the prefix by 4 bits (making it /20), and returns the first block — `172.16.0.0/20`. The next call with index 1 returns `172.16.16.0/20`, and so on. This is how subnets are carved out automatically without manually calculating ranges.

The practical rule: a smaller prefix number means a larger network (more IPs). A larger prefix number means a smaller, more specific network.

---

## IP Routing

Routing is the process of deciding where network traffic should go next. Every network — including your AWS VPC uses a route table to make this decision.

A route table is a list of rules. Each rule says: "if the destination IP matches this range, send the traffic to this target." When a packet arrives, the router checks the destination IP against the rules from most specific to least specific, and forwards accordingly.

In AWS, every subnet is associated with a route table. The most important route in any public subnet looks like this:

```
Destination: 0.0.0.0/0    Target: Internet Gateway
```

This means: "for any destination not matched by a more specific rule, send the traffic to the Internet Gateway." `0.0.0.0/0` is the default route — it matches everything.

For private subnets, the default route points to the NAT Gateway instead:

```
Destination: 0.0.0.0/0    Target: NAT Gateway
```

This allows private instances to reach the internet for outbound requests while remaining unreachable from the internet for inbound connections.

Local traffic within the VPC is handled automatically. AWS adds a local route (`172.16.0.0/16 → local`) to every route table so that instances within the same VPC can always talk to each other without going through any gateway.

---

## Internet Gateways

An Internet Gateway (IGW) is an AWS-managed component you attach to a VPC to enable communication between resources inside the VPC and the internet.

It serves two functions:
1. It provides a target in route tables for internet-bound traffic
2. It performs Network Address Translation for instances with public IPs — translating their private IP to their public IP for outbound traffic and reversing it for inbound responses

One IGW per VPC is the rule. If a subnet's route table has a route pointing to the IGW, it is a public subnet. If it does not, it is a private subnet — even if the resources inside have public IPs assigned, they cannot reach the internet without that route.

In Terraform: `aws_internet_gateway` attaches to the VPC, and then `aws_route` creates the `0.0.0.0/0 → igw` rule in the public route table.

---

## NAT (Network Address Translation)

NAT is the mechanism that allows devices with private IP addresses to communicate with the internet without being directly exposed to it.

**How it works:** When a private instance (e.g., `172.16.32.5`) sends a request to an external server, the NAT Gateway intercepts the packet, replaces the source IP with its own public Elastic IP, and forwards the request. When the response comes back, NAT reverses the translation and delivers it to the original private instance. The external server only ever sees the NAT Gateway's public IP — never the private instance's address.

**NAT Gateway vs NAT Instance:** AWS offers NAT Gateway (a fully managed service) and NAT Instance (an EC2 you manage yourself). NAT Gateway is the standard choice — it scales automatically, is highly available within an AZ, and requires no patching.


**The architecture rule:** NAT Gateway lives in a public subnet (it needs an outbound internet path) but serves private subnets. Private instances route their internet-bound traffic to it. It is a one-way door — outbound works, inbound does not.
