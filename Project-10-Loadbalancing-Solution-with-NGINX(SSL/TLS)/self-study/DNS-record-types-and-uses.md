# DNS Record Types - Reference Guide

## What is DNS?

The Domain Name System (DNS) translates human-readable domain names (like `example.com`) into IP addresses that computers use to identify each other on the network.

---

## Common DNS Record Types

### 1. A Record (Address Record)
**Purpose:** Maps a domain name to an IPv4 address.

**Example:**
```
example.com.    IN    A    192.0.2.1
```

**Use Case:**
- Point `example.com` to your web server's IP address
- Most common record type for websites

---

### 2. AAAA Record (IPv6 Address Record)
**Purpose:** Maps a domain name to an IPv6 address.

**Example:**
```
example.com.    IN    AAAA    2001:0db8:85a3:0000:0000:8a2e:0370:7334
```

**Use Case:**
- IPv6 version of the A record
- Used as IPv6 adoption increases

---

### 3. CNAME Record (Canonical Name)
**Purpose:** Creates an alias from one domain name to another.

**Example:**
```
www.example.com.    IN    CNAME    example.com.
```

**Use Case:**
- Point `www.example.com` to `example.com`
- Redirect multiple subdomains to one canonical domain
- **Note:** Cannot be used for root domain (@)

---

### 4. MX Record (Mail Exchange)
**Purpose:** Specifies mail servers responsible for receiving email for a domain.

**Example:**
```
example.com.    IN    MX    10 mail1.example.com.
example.com.    IN    MX    20 mail2.example.com.
```

**Use Case:**
- Configure email delivery for your domain
- Priority number (10, 20) determines mail server preference (lower = higher priority)

---

### 5. TXT Record (Text Record)
**Purpose:** Stores text information for various purposes.

**Example:**
```
example.com.    IN    TXT    "v=spf1 include:_spf.google.com ~all"
```

**Use Cases:**
- **SPF (Sender Policy Framework):** Prevent email spoofing
- **DKIM:** Email authentication
- **Domain verification:** Prove domain ownership to services like Google, Microsoft
- **DMARC:** Email authentication policy

---

### 6. NS Record (Name Server)
**Purpose:** Specifies authoritative DNS servers for a domain.

**Example:**
```
example.com.    IN    NS    ns1.example.com.
example.com.    IN    NS    ns2.example.com.
```

**Use Case:**
- Delegate DNS management to specific nameservers
- Required for every domain

---

### 7. SOA Record (Start of Authority)
**Purpose:** Contains administrative information about the DNS zone.

**Example:**
```
example.com.    IN    SOA    ns1.example.com. admin.example.com. (
                              2024102501  ; Serial
                              3600        ; Refresh
                              1800        ; Retry
                              604800      ; Expire
                              86400 )     ; Minimum TTL
```

**Use Case:**
- Defines primary nameserver
- Contains zone transfer timing information
- Automatically created for each domain

---

### 8. PTR Record (Pointer Record)
**Purpose:** Reverse DNS lookup - maps an IP address to a domain name.

**Example:**
```
1.2.0.192.in-addr.arpa.    IN    PTR    example.com.
```

**Use Case:**
- Email server verification (prevents spam filtering)
- Network troubleshooting
- Security and logging

---

### 9. SRV Record (Service Record)
**Purpose:** Defines location of specific services.

**Example:**
```
_service._proto.example.com.    IN    SRV    10 5 5060 sipserver.example.com.
```

**Use Cases:**
- VoIP services (SIP)
- XMPP/Jabber messaging
- Microsoft Active Directory
- Format: priority weight port target

---

### 10. CAA Record (Certification Authority Authorization)
**Purpose:** Specifies which Certificate Authorities can issue SSL certificates for a domain.

**Example:**
```
example.com.    IN    CAA    0 issue "letsencrypt.org"
example.com.    IN    CAA    0 issuewild "letsencrypt.org"
```

**Use Case:**
- Improve security by restricting SSL certificate issuance
- Prevent unauthorized certificate issuance

---

### 11. ALIAS Record (Virtual Record)
**Purpose:** Similar to CNAME but can be used at the root domain level.

**Example:**
```
example.com.    IN    ALIAS    loadbalancer.example.com.
```

**Use Case:**
- Point root domain to another hostname
- Alternative to CNAME for apex domain
- **Note:** Not standard DNS, provider-specific (Route53, Cloudflare)

---

## DNS Record Syntax Components

```
NAME            TTL    CLASS    TYPE    VALUE
example.com.    3600   IN       A       192.0.2.1
```

- **NAME:** Domain or subdomain
- **TTL (Time To Live):** How long (in seconds) to cache the record
- **CLASS:** Almost always `IN` (Internet)
- **TYPE:** Record type (A, AAAA, CNAME, etc.)
- **VALUE:** The data for the record

---

## Common TTL Values

| TTL Value | Duration | Use Case |
|-----------|----------|----------|
| 60 | 1 minute | Testing, frequent changes |
| 300 | 5 minutes | During migrations |
| 3600 | 1 hour | Standard setting |
| 86400 | 24 hours | Stable, rarely changing records |

---

## DNS Record Priority in Load Balancing Project

For the Nginx Load Balancer with SSL/TLS project:

1. **A Record:** Points your domain (`mytoolbox.mooo.com`) to Elastic IP
2. **TXT Record:** May be used for domain verification (if needed)
3. **CAA Record:** Allows Let's Encrypt to issue certificates
4. **MX Record:** Optional, if you want email for your domain

---

## Quick Reference Commands

### Query DNS Records (Linux/Mac)
```bash
# Query A record
nslookup example.com

# Query specific record type
dig example.com MX
dig example.com TXT

# Detailed DNS lookup
host -a example.com
```

### Query DNS Records (Windows)
```cmd
# Query A record
nslookup example.com

# Query specific record type
nslookup -type=MX example.com
nslookup -type=TXT example.com
```

---

## Best Practices

1. ✅ **Use A records** for direct IP mapping
2. ✅ **Use CNAME** for subdomains that point to other domains
3. ✅ **Set appropriate TTL** values (lower during changes, higher when stable)
4. ✅ **Configure CAA records** for SSL certificate security
5. ✅ **Keep NS records** updated with your DNS provider
6. ✅ **Use SPF/DKIM/DMARC** TXT records for email security
7. ❌ **Don't use CNAME** at the root domain (use A or ALIAS instead)
8. ❌ **Don't set TTL too low** permanently (increases DNS query load)

---

## Summary

DNS records are the backbone of internet addressing and service routing. Understanding different record types helps you:

- Configure domains correctly
- Troubleshoot connectivity issues
- Secure email and SSL certificates
- Implement load balancing and failover
- Verify domain ownership for services

For the load balancer project, the **A record** is most critical - it maps your domain name to your Nginx server's Elastic IP address.
