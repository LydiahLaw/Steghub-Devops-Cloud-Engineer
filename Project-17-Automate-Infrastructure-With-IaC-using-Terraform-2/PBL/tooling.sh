#!/bin/bash
yum update -y
yum install -y httpd php php-mysqlnd git
systemctl start httpd
systemctl enable httpd
