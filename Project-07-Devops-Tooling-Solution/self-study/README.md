# Storage Types and Protocols

## Network-Attached Storage (NAS)
NAS is a storage device that connects to a network and provides file-level storage. Multiple users and systems can access shared data over standard Ethernet. It is simple to manage and often used for collaboration and file sharing.

Common NAS protocols:
- NFS (Network File System) – commonly used in Linux/Unix environments
- SMB/CIFS (Server Message Block) – commonly used in Windows environments
- FTP/SFTP – used to transfer files between systems

## Storage Area Network (SAN)
A SAN is a high-speed network that provides block-level storage to servers. The storage appears to the operating system as if it were a locally attached disk. SANs are used for applications that require high performance and low latency, such as databases.

Common SAN protocols:
- iSCSI (Internet Small Computer Systems Interface) – block-level storage over IP
- Fibre Channel – high-speed networking technology used for SANs

## Block-Level Storage
Block storage splits data into fixed-size chunks (blocks). The operating system organizes these blocks into files. In the cloud, block storage is commonly used for databases, virtual machine disks, and applications requiring consistent performance.

Example: Amazon EBS (Elastic Block Store) provides block storage volumes for EC2 instances.

## Object Storage
Object storage manages data as objects, each containing the file, metadata, and a unique identifier. It is accessed via APIs and scales almost infinitely. Object storage is well-suited for backups, static website hosting, and storing large volumes of unstructured data.

Example: Amazon S3 (Simple Storage Service) is an object storage service.

## File System Storage
File storage organizes data into a hierarchical structure of files and directories. It is typically shared over a network and accessed using file-level protocols. File storage is ideal for content management systems, development environments, and shared directories.

Example: Amazon EFS (Elastic File System) provides scalable file storage using NFS.

## Differences Between Block, Object, and File System Storage

| Feature        | Block Storage (EBS)     | Object Storage (S3)               | File System Storage (EFS)        |
|----------------|-------------------------|-----------------------------------|----------------------------------|
| Data Access    | Raw blocks              | Objects via API/HTTP              | Files via NFS/SMB                |
| Structure      | Managed by OS (file system on top) | Flat namespace with metadata     | Hierarchical (folders/files)     |
| Performance    | Low latency, high performance | High scalability, less latency-sensitive | Moderate, good for shared access |
| Use Cases      | Databases, VM disks     | Backups, media, static websites   | Shared content, development, collaboration |

## Factors That Determine the Most Appropriate Storage Solution
- Type of data (structured, unstructured, large files, small files)
- Performance requirements (low latency vs high scalability)
- Access method (block-level, file-level, or API-based)
- Cost considerations
- Scalability needs
- Data sharing and collaboration requirements
- Security and compliance needs

## AWS Service Mapping
- Block storage → Amazon EBS
- Object storage → Amazon S3
- File storage → Amazon EFS
